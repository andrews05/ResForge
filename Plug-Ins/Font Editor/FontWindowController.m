#import "FontWindowController.h"

static UInt32 TableChecksum(UInt32 *table, UInt32 length)
{
	UInt32 sum = 0, nLongs = (length+3) >> 2;
	while(nLongs-- > 0) sum += *table++;
	return sum;
}

@implementation FontWindowController
@synthesize resource;

- (instancetype)initWithResource:(Resource *)inResource
{
	self = [self initWithWindowNibName:@"FontDocument"];
	if(!self) return nil;
	
	resource = inResource;
	headerTable = [[NSMutableArray alloc] init];
	[self loadFontFromResource];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:self.window];

	return self;
}

- (void)loadFontFromResource
{
	char *start = (char *)[[resource data] bytes];
	if (start != 0x0)
	{
		arch = CFSwapInt32BigToHost(*(OSType*)start);
		numTables = CFSwapInt16BigToHost(*(UInt16*)(start+4));
		searchRange = CFSwapInt16BigToHost(*(UInt16*)(start+6));
		entrySelector = CFSwapInt16BigToHost(*(UInt16*)(start+8));
		rangeShift = CFSwapInt16BigToHost(*(UInt16*)(start+10));
		UInt32 *pos = (UInt32 *)(start+12);
#if 0
		printf("%s\n", [[self displayName] cString]);
		printf("  architecture: %#lx '%.4s'\n", arch, &arch);
		printf("  number of tables: %hu\n", numTables);
		printf("  searchRange: %hu\n", searchRange);
		printf("  entrySelector: %hu\n", entrySelector);
		printf("  rangeShift: %hu\n\n", rangeShift);
#endif
		for(int i = 0; i < numTables; i++)
		{
			OSType name = *pos++;
			UInt32 checksum = CFSwapInt32BigToHost(*pos++);
			UInt32 offset = CFSwapInt32BigToHost(*pos++);
			UInt32 length = CFSwapInt32BigToHost(*pos++);
			[headerTable addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[[NSString alloc] initWithBytes:&name length:4 encoding:NSMacOSRomanStringEncoding], @"name",
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:@"ResourceDataDidChangeNotification" object:resource];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
    NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	
	[createItem setTitle: NSLocalizedString(@"Add Font Table…", nil)];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
    NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	
	[createItem setTitle: NSLocalizedString(@"Create New Resource…", nil)];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	[headerTable removeAllObjects];
	[self loadFontFromResource];
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
	NSInteger offset = 12 + ([headerTable count] << 4);
	
	// add table index
	for(int i = 0; i < numTables; i++)
	{
		NSMutableDictionary *table = headerTable[i];
		NSData *tableData = [table valueForKey:@"data"];
		UInt32 length = (UInt32)[tableData length];
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
		[data appendData:[headerTable[i] valueForKey:@"data"]];
		if([data length] % 4)	// pads the last table too... oh well
			[data appendBytes:&align length:4-([data length]%4)];
	}
	
	// write checksum adjustment to head table
    NSUInteger index = [[headerTable valueForKey:@"name"] indexOfObject:@"head"];
	if(index != NSNotFound)
	{
        NSDictionary *head = headerTable[index];
		UInt32 fontChecksum = 0;
		NSRange csRange = NSMakeRange([[head valueForKey:@"offset"] unsignedLongValue]+8,4);
		[data replaceBytesInRange:csRange withBytes:&fontChecksum length:4];
		fontChecksum = TableChecksum((UInt32 *)[data bytes], (UInt32)[data length]);
		[data replaceBytesInRange:csRange withBytes:&fontChecksum length:4];
	}
//	[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:backup];
	[resource setData:data];
//	[backup setData:[data copy]];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:backup];
	[self setDocumentEdited:NO];
}

- (IBAction)createNewItem:(id)sender
{
    [self addFontTable:@"head"];
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
	
	[self openTable:headerTable[[sender clickedRow]] inEditor:YES];
}

- (void)openTable:(NSDictionary *)table inEditor:(BOOL)editor
{
	NSData *data = [table valueForKey:@"data"];
	if (data)
	{
        Resource *tableResource = [[Resource alloc] initWithType:[@"sfnt." stringByAppendingString:[table valueForKey:@"name"]] id:0 name:[NSString stringWithFormat:NSLocalizedString(@"%@ >> %@", nil), [resource name], [table valueForKey:@"name"]] attributes:0 data:[table valueForKey:@"data"]];
		if (!tableResource)
		{
			NSLog(@"Couldn't create Resource with data for table '%@'.", [table valueForKey:@"name"]);
			return;
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableDataDidChange:) name:@"ResourceDataDidChangeNotification" object:tableResource];
        id <ResKnifePluginManager> manager = self.resource.manager;
		if (editor)	[manager openWithResource:tableResource using:nil template:nil];
//		else		[(id)[resource document] openResource:tableResource usingTemplate:[NSString stringWithFormat:@"sfnt subtable '%@'", [table valueForKey:@"name"]]];
	}
}

- (void)tableDataDidChange:(NSNotification *)notification
{
	[self setTableData:[notification object]];
}

- (void)setTableData:(Resource *)tableResource
{
    NSString *type = [tableResource.type substringFromIndex:5];
    NSUInteger index = [[headerTable valueForKey:@"name"] indexOfObject:type];
	if(index == NSNotFound)
	{
		NSLog(@"Couldn't retrieve table with name '%@'.", type);
		return;
	}
	
    NSDictionary *table = headerTable[index];
//	id undoResource = [tableResource copy];
//	[undoResource setData:[table valueForKey:@"data"]];
//	[[[resource document] undoManager] registerUndoWithTarget:resource selector:@selector(setTableData:) object:undoResource];
//	[[[resource document] undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Edit of table '%@'", nil), type]];
	[table setValue:[tableResource data] forKey:@"data"];
	[self setDocumentEdited:YES];
}

+ (NSString *)filenameExtensionFor:(NSString *)resourceType
{
    if([resourceType isEqualToString:@"sfnt"]) return @"ttf";
	else return resourceType;
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
