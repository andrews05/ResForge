#import "PasteboardDocument.h"
#import "Resource.h"

extern NSString *RKResourcePboardType;

@implementation PasteboardDocument

- (id)init
{
	self = [super init];
	if( self )
	{
		[self readPasteboard:NSGeneralPboard];
	}
	return self;
}

-(void)readPasteboard:(NSString *)pbName
{
	// this method is mostly a duplicate of -[ResourceDocument paste:] but takes a pasteboard name for an argument
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:pbName];
	NSEnumerator *enumerator = [[pb types] objectEnumerator];
	NSString *pbType;
	
	// clear current pasteboard representation
	//[self selectAll:nil];
	[self clear:nil];
	
	// set the window's title to represent the pasteboard being shown (at some point I anticipate having several of these)
	[[self mainWindow] setTitle:pbName];
	
	// disable undos during loading
	[[self undoManager] disableUndoRegistration];
	
	// get all types off the pasteboard
	while( pbType = [enumerator nextObject] )
	{
		// 'paste' any resources into pbdoc's data source
		if( [pbType isEqualToString:RKResourcePboardType] )
			[self pasteResources:[NSUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
		else
		{
			// create the faux resource & add it to the array
			Resource *resource = [Resource resourceOfType:nil andID:nil withName:pbType andAttributes:nil data:[pb dataForType:pbType]];
			[resources addObject:resource];		// array retains resource
		}
	}
	
	// re-enable undos
	[[self undoManager] enableUndoRegistration];
	
	[outlineView reloadData];
}

-(void)windowDidBecomeKey:(NSNotification *)notification
{
	// This mess sponsored by Uli Kusterer ;-)
	generalChangeCount = [[NSPasteboard generalPasteboard] changeCount];
	[resources removeAllObjects];
	
	[self readPasteboard:NSGeneralPboard];	// Update window contents.
}


@end
