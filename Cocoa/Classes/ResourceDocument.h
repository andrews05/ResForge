#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework
#import "ResourceDataSource.h"

@interface ResourceDocument : NSDocument
{
	IBOutlet NSOutlineView		*outlineView;
	IBOutlet ResourceDataSource	*dataSource;
	
	NSMutableArray	*resources;
	BOOL			saveToDataFork;
	HFSUniStr255	*otherFork;		// name of fork to save to if not using data fork (usually 'RESOURCE_FORK' as returned from FSGetResourceForkName() -- ignored if saveToDataFork is YES )
}

- (void)setupToolbar:(NSWindowController *)controller;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)openResource:(id)sender;
- (IBAction)openResourceAsHex:(id)sender;
- (IBAction)playSound:(id)sender;
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finished;

- (BOOL)readResourceMap:(SInt16)fileRefNum;
- (BOOL)writeResourceMap:(SInt16)fileRefNum;

- (NSOutlineView *)outlineView;
- (ResourceDataSource *)dataSource;
- (NSArray *)resources;		// return the array as non-mutable

@end