#import "FontWindowController.h"
#import "NGSCategories.h"
#import "ResourceDocument.h"
#import "Resource.h"
#import <stdarg.h>

UInt32 TableChecksum(UInt32 *table, UInt32 length)
{
	UInt32 sum = 0, nLongs = (length+3) >> 2;
	while(nLongs-- > 0) sum += *table++;
	return sum;
}

@implementation FontWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)inResource
{
	self = [self initWithWindowNibName:@"FontDocument"];
	if(!self) return nil;
	
	resource = [(id)inResource retain];
	headerTable = [[NSMutableArray alloc] init];
	[self loadFontFromResource];
	
	// load the window from the nib
	[self window];
	return self;
}

- (void)loadFontFromResource
{
	char *start = (char *)[[resource data] bytes];
	if (start != 0x0)
	{
		arch = *(OSType*)start;
		numTables = *(UInt16*)(start+4);
		searchRange = *(UInt16*)(start+6);
		entrySelector = *(UInt16*)(start+8);
		rangeShift = *(UInt16*)(start+10);
		UInt32 *pos = (UInt32 *)(start+12);
/*		printf("%s\n", [[self displayName] cString]);
		printf("  architecture: %#lx '%.4s'\n", arch, &arch);
		printf("  number of tables: %hu\n", numTables);
		printf("  searchRange: %hu\n", searchRange);
		printf("  entrySelector: %hu\n", entrySelector);
		printf("  rangeShift: %hu\n\n", rangeShift);
*/		for(int i = 0; i < numTables; i++)
		{
			OSType name = *pos++;
			UInt32 checksum = *pos++;
			UInt32 offset = *pos++;
			UInt32 length = *pos++;
			[headerTable addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[[[NSString alloc] initWithBytes:&name length:4 encoding:NSMacOSRomanStringEncoding] autorelease], @"name",
				@(checksum), @"checksum",
				@(offset), @"offset",
				@(length), @"length",
				[NSData dataWithBytes:start+offset length:length], @"data",
				nil]];
		}
	}
	else
	{
		NSLog(@"Invalid sfnt, aborting parse.");
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource release];
	[headerTable release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
	if(![[resource name] isEqualToString:@""])
	{
		[[self window] setTitle:[resource name]];
		//SetWindowAlternateTitle((WindowRef) [[self window] windowRef], (CFStringRef) [NSString stringWithFormat:NSLocalizedString(@"%@ %@: '%@'", nil), [resource type], [resource resID], [resource name]]);
	}
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemAtIndex:[resourceMenu indexOfItemWithTarget:nil andAction:@selector(showCreateResourceSheet:)]];
	
	[createItem setTitle: NSLocalizedString(@"Add Font Table...", nil)];
	[createItem setAction:@selector(showAddFontTableSheet:)];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemAtIndex:[resourceMenu indexOfItemWithTarget:nil andAction:@selector(showAddFontTableSheet:)]];
	
	[createItem setTitle: NSLocalizedString(@"Create New Resource...", nil)];
	[createItem setAction:@selector(showCreateResourceSheet:)];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	[headerTable removeAllObjects];
	[self loadFontFromResource];
}

- (BOOL)windowShouldClose:(id)sender
{
	if([[self window] isDocumentEdited])
	{
		NSBeginAlertSheet(@"Do you want to keep the changes you made to this font?", @"Keep", @"Don't Keep", @"Cancel", sender, self, @selector(saveSheetDidClose:returnCode:contextInfo:), nil, nil, @"Your changes cannot be saved later if you don't keep them.");
		return NO;
	}
	else return YES;
}

- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch(returnCode)
	{
		case NSAlertDefaultReturn:		// keep
			[self saveResource:nil];
			[[self window] close];
			break;
		
		case NSAlertAlternateReturn:	// don't keep
			[[self window] close];
			break;
		
		case NSAlertOtherReturn:		// cancel
			break;
	}
}

- (void)saveResource:(id)sender
{
	// write header fields
	NSMutableData *data = [NSMutableData data];
	[data appendBytes:&arch length:4];
	[data appendBytes:&numTables length:2];
	[data appendBytes:&searchRange length:2];
	[data appendBytes:&entrySelector length:2];
	[data appendBytes:&rangeShift length:2];
	UInt32 offset = 12 + ([headerTable count] << 4);
	
	// add table index
	for(int i = 0; i < numTables; i++)
	{
		NSMutableDictionary *table = [headerTable objectAtIndex:i];
		NSData *tableData = [table valueForKey:@"data"];
		UInt32 length = [tableData length];
		UInt32 checksum = TableChecksum((UInt32 *)[tableData bytes], length);
		[table setValue:@(checksum) forKey:@"checksum"];
		[table setValue:@(offset) forKey:@"offset"];
		[table setValue:@(length) forKey:@"length"];
		[data appendBytes:[[table valueForKey:@"name"] cStringUsingEncoding:NSMacOSRomanStringEncoding] length:4];
		[data appendBytes:&checksum length:4];
		[data appendBytes:&offset length:4];
		[data appendBytes:&length length:4];
		offset += length;
		if(offset % 4)
			offset += 4-(offset%4);
	}
	
	// append tables
	long align = 0;
	for(int i = 0; i < numTables; i++)
	{
		// note that this doesn't output in the order thet they were read, nor align on long boundries
		[data appendData:[[headerTable objectAtIndex:i] valueForKey:@"data"]];
		if([data length] % 4)	// pads the last table too... oh well
			[data appendBytes:&align length:4-([data length]%4)];
	}
	
	// write checksum adjustment to head table
	NSDictionary *head = [headerTable firstObjectReturningValue:@"head" forKey:@"name"];
	if(head)
	{
		UInt32 fontChecksum = 0;
		NSRange csRange = NSMakeRange([[head valueForKey:@"offset"] unsignedLongValue]+8,4);
		[data replaceBytesInRange:csRange withBytes:&fontChecksum length:4];
		fontChecksum = TableChecksum((UInt32 *)[data bytes], [data length]);
		[data replaceBytesInRange:csRange withBytes:&fontChecksum length:4];
	}
//	[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:backup];
	[resource setData:data];
//	[backup setData:[data copy]];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:backup];
	[self setDocumentEdited:NO];
}

- (IBAction)showAddFontTableSheet:(id)sender
{

}

- (void)addFontTable:(NSString *)name
{
	NSMutableDictionary *table = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						name, @"name",
						@(0), @"checksum",
						@(0), @"offset",
						@(0), @"length",
						[NSData data], @"data", nil];
	[headerTable addObject:table];
	numTables = (UInt16)[headerTable count];
	[self openTable:table inEditor:YES];
	[self setDocumentEdited:YES];
}

- (void)openTableInEditor:(NSTableView *)sender
{
	if([sender action])
	{
		// action set in IB but swapped at first click for a doubleAction ;)
		[sender setAction:nil];
		[sender setDoubleAction:@selector(openTableInEditor:)];
		return;
	}
	
	[self openTable:[headerTable objectAtIndex:[sender clickedRow]] inEditor:YES];
}

- (void)openTable:(NSDictionary *)table inEditor:(BOOL)editor
{
	NSData *data = [table valueForKey:@"data"];
	if (data)
	{
		id tableResource = [NSClassFromString(@"Resource") resourceOfType:GetOSTypeFromNSString([table valueForKey:@"name"]) andID:0 withName:[NSString stringWithFormat:NSLocalizedString(@"%@ >> %@", nil), [resource name], [table valueForKey:@"name"]] andAttributes:0 data:[table valueForKey:@"data"]];
		if (!tableResource)
		{
			NSLog(@"Couldn't create Resource with data for table '%@'.", [table valueForKey:@"name"]);
			return;
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableDataDidChange:) name:ResourceDataDidChangeNotification object:tableResource];
		if (editor)	[(id)[resource document] openResourceUsingEditor:tableResource];
		else		[(id)[resource document] openResource:tableResource usingTemplate:[NSString stringWithFormat:@"sfnt subtable '%@'", [table valueForKey:@"name"]]];
	}
}

- (void)tableDataDidChange:(NSNotification *)notification
{
	[self setTableData:[notification object]];
}

- (void)setTableData:(id <ResKnifeResourceProtocol>)tableResource
{
	NSDictionary *table = [headerTable firstObjectReturningValue:GetNSStringFromOSType([tableResource type]) forKey:@"name"];
	if(!table)
	{
		NSLog(@"Couldn't retrieve table with name '%@'.", GetNSStringFromOSType([tableResource type]));
		return;
	}
	
	id undoResource = [[tableResource copy] autorelease];
	[undoResource setData:[table valueForKey:@"data"]];
	[[[resource document] undoManager] registerUndoWithTarget:resource selector:@selector(setTableData:) object:undoResource];
	[[[resource document] undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Edit of table '%@'", nil), [tableResource type]]];
	[table setValue:[tableResource data] forKey:@"data"];
	[self setDocumentEdited:YES];
}

+ (NSString *)filenameExtensionForFileExport:(id <ResKnifeResourceProtocol>)resource
{
	if([resource type] == 'sfnt') return @"ttf";
	else return GetNSStringFromOSType([resource type]);
}

@end

/*	sfnt_header *header = (sfnt_header *) [[resource data] bytes];
	for(int i = 0; i < header->tableCount; i++)
	{
		switch(header->tableInfo[i].tagname)
		{
			case 'name':
				name_table_header *name_table = (name_table_header *) (((char *)[[resource data] bytes]) + header->tableInfo[i].offset);
				NSMutableArray *nameArray = [NSMutableArray array];
				for(int j = 0; j < name_table->record_count; j++)
				{
					// load names into array of name_record classes
					NSMutableDictionary *name = [NSMutableDictionary dictionary];
					NSData *stringData = [NSData dataWithBytes:((char *)name_table + name_table->names[j].offset) length:name_table->names[j].length];
					NSStringEncoding stringEncoding;
					switch(name_table->names[j].platform_id)
					{
						case 0: // unicode
							stringEncoding = NSUnicodeStringEncoding;
							break;
						case 1: // mac - values originally were smScript values, which are equivalent to CFStringEncoding values
							stringEncoding = CFStringConvertEncodingToNSStringEncoding(name_table->names[j].platform_specific_id);
							break;
						case 2: // ISO
							switch(name_table->names[j].platform_specific_id)
							{
								case 0:		stringEncoding = NSASCIIStringEncoding;			break;
								case 1:		stringEncoding = NSUnicodeStringEncoding;		break;  // ISO 10646
								case 2:		stringEncoding = NSISOLatin1StringEncoding;		break;  // ISO 8859-1
								default:	stringEncoding = NSASCIIStringEncoding;			break;
							}
							break;
						case 2: // windows
							switch(name_table->names[j].platform_specific_id)
							{
								// bug: should use correct encodings here
								default:	stringEncoding = NSWindowsCP1252StringEncoding;	break;
							}
							break;
						default:	// undefined
							stringEncoding = NSWindowsCP1250StringEncoding; // guess Win-Latin-2 
							break;
					}
					[name setValue:[NSNumber numberWithUnsignedShort:name_table->names[j].platform_id]			forKey:@"platform"];
					[name setValue:[NSNumber numberWithUnsignedShort:name_table->names[j].platform_specific_id] forKey:@"specific"];
					[name setValue:[NSNumber numberWithUnsignedShort:name_table->names[j].language_id]			forKey:@"language"];
					[name setValue:[NSNumber numberWithUnsignedShort:name_table->names[j].name_id]				forKey:@"name"];
					[name setValue:[NSString stringWithData:stringData encoding:stringEncoding]]				forKey:@"string"];
					[nameArray addObject:name];
				}
				[tables setObject:nameArray forKey:@"name"];
				break;
			
			default:
				// else just save the data of the table
				[tables setObject:[NSData dataWithBytes:(((char *)[[resource data] bytes]) + header->tableInfo[i].offset) length:header->tableInfo[i].length] forKey:[NSString stringWithCString:&(header->tableInfo[i].tagname) length:4]];
				break;
		}
	}
*/