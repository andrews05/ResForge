#import "NovaWindowController.h"
#import "BoomWindowController.h"
#import "CharWindowController.h"
#import "ColrWindowController.h"
#import "CronWindowController.h"
#import "DescWindowController.h"

@implementation NovaWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	id oldSelf = self;
	NSData *classData = [[(id <ResKnifeResourceProtocol>)newResource type] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *className = [[[NSString stringWithCString:[classData bytes] length:[classData length]] capitalizedString] stringByAppendingString:@"WindowController"];
	if( [className isEqualToString:@"Yea(R)WindowController"] ) className = @"YearWindowController"; // lossy conversion turns ¨ into (R), so i have to special-case Ø‘Š¨
	self = [[NSClassFromString(className) alloc] initWithResource:newResource];
	[oldSelf release];
	if( !self ) return nil;
	
	// do global stuff here
	resource = [(id)newResource retain];
	undoManager = [[NSUndoManager alloc] init];
//	localCenter = [[NSNotificationCenter alloc] init];
	plugBundle = [NSBundle bundleForClass:[self class]];
//	plugBundle = [NSBundle bundleWithIdentifier:@"au.com.sutherland-studios.resknife.novatools"];
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( [newResource name] && ![[newResource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", [[self window] title], [newResource name]]];
	return self;
}

- (id)initWithResources:(id <ResKnifeResourceProtocol>)newResource, ...
{
	return nil;
}

- (void)dealloc
{
//	[localCenter release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[undoManager release];
	[shipDataSource release];
	[soundDataSource release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// create the data sources (here because this is called just before they are applied to the combo boxes)
	descriptionDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"desc" value:@"" table:@"Resource Types"]];
	governmentDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"govt" value:@"" table:@"Resource Types"]];
	pictureDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"PICT" value:@"" table:@"Resource Types"]];
	planetDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"spob" value:@"" table:@"Resource Types"]];
	shipDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"ship" value:@"" table:@"Resource Types"]];
	soundDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"snd" value:@"" table:@"Resource Types"]];
	spinDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"spin" value:@"" table:@"Resource Types"]];
	
	// we don't want this notification until we have a window!
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	// bug: only registers for notifications on the resource we're editing, need dependant resources too (pass nil for object?)
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

- (BOOL)windowShouldClose:(id)sender
{
	if( [[self window] isDocumentEdited] )
	{
		NSDictionary *errorValues = [self validateValues];
		NSArray *fields = [errorValues allKeys];	// bug: order of items in array is not guaranteed
		NSArray *descriptions = [errorValues allValues];
		switch( [errorValues count] )
		{
			case 0:
				NSBeginAlertSheet( @"Do you want to save the changes you made to this resource?", @"Save", @"DonÕt Save", @"Cancel", sender, self, @selector(saveSheetDidClose:returnCode:contextInfo:), nil, nil, @"Your changes will be lost if you don't save them." );
				break;
			
			case 1:
				NSBeginAlertSheet( @"Invalid values, changes cannot be saved.", @"Cancel", @"Discard Changes", nil, sender, self, @selector(invalidValuesSheetDidClose:returnCode:contextInfo:), nil, nil, @"An invalid value has been given for one of the resource's items. The following field has it's value set incorrectly:\n\n%@: %@", [fields objectAtIndex:0], [descriptions objectAtIndex:0] );
				break;
			
			case 2:
				NSBeginAlertSheet( @"Invalid values, changes cannot be saved.", @"Cancel", @"Discard Changes", nil, sender, self, @selector(invalidValuesSheetDidClose:returnCode:contextInfo:), nil, nil, @"There are invalid values given for a couple of the resource's items. The following fields have their values set incorrectly:\n\n%@: %@\n%@: %@", [fields objectAtIndex:0], [descriptions objectAtIndex:0], [fields objectAtIndex:1], [descriptions objectAtIndex:1] );
				break;
			
			case 3:
				NSBeginAlertSheet( @"Invalid values, changes cannot be saved.", @"Cancel", @"Discard Changes", nil, sender, self, @selector(invalidValuesSheetDidClose:returnCode:contextInfo:), nil, nil, @"There are invalid values given for three of the resource's items. The following fields have their values set incorrectly:\n\n%@: %@\n%@: %@\n%@: %@", [fields objectAtIndex:0], [descriptions objectAtIndex:0], [fields objectAtIndex:1], [descriptions objectAtIndex:1], [fields objectAtIndex:2], [descriptions objectAtIndex:2] );
				break;
			
			default:
				NSBeginAlertSheet( @"Invalid values, changes cannot be saved.", @"Cancel", @"Discard Changes", nil, sender, self, @selector(invalidValuesSheetDidClose:returnCode:contextInfo:), nil, nil, @"There are invalid values given for many of the resource's items. The following fields have their values set incorrectly:\n\n%@: %@\n%@: %@\n%@: %@\nplus others.", [fields objectAtIndex:0], [descriptions objectAtIndex:0], [fields objectAtIndex:1], [descriptions objectAtIndex:1], [fields objectAtIndex:2], [descriptions objectAtIndex:2] );
				break;
		}
		return NO;
	}
	else return YES;
}

- (void)setResource:(id <ResKnifeResourceProtocol>)newResource
{
	id old = resource;
	resource = [(id)newResource retain];
	[old release];
}

- (void)setUndoManager:(NSUndoManager *)newUndoManager
{
	id old = undoManager;
	undoManager = [newUndoManager retain];
	[old release];
}

- (IBAction)toggleResID:(id)sender
{
	// toggles between resource IDs and index numbers
	NSLog( @"%@", [resource type] );
}

- (void)resourceNameDidChange:(NSNotification *)notification
{
	NSString *prefix;
	NSScanner *scanner = [NSScanner scannerWithString:[[self window] title]];
	if( ![scanner scanUpToString:@":" intoString:&prefix] )
		prefix = [[self window] title];
	if( ![[(id <ResKnifeResourceProtocol>)[notification object] name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", prefix, [(id <ResKnifeResourceProtocol>)[notification object] name]]];
	else [[self window] setTitle:prefix];
}

- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch( returnCode )
	{
		case NSAlertDefaultReturn:		// save
			[self saveResource];
			[[self window] close];
			break;
		
		case NSAlertAlternateReturn:	// don't save
			[[self window] close];
			break;
		
		case NSAlertOtherReturn:		// cancel
			break;
	}
}

- (void)invalidValuesSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch( returnCode )
	{
		case NSAlertDefaultReturn:		// cancel
			break;
		
		case NSAlertAlternateReturn:	// discard changes
			[[self window] close];
			break;
	}
}

@end
