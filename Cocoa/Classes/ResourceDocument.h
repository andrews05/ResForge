#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework

@class ResourceWindowController, ResourceDataSource;

@interface ResourceDocument : NSDocument
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;
	
	NSMutableArray	*resources;
	BOOL			saveToDataFork;
	HFSUniStr255	*otherFork;		// name of fork to save to if not using data fork (usually 'RESOURCE_FORK' as returned from FSGetResourceForkName() -- ignored if saveToDataFork is YES )
}

- (void)setupToolbar:(NSWindowController *)windowController;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)openResource:(id)sender;
- (IBAction)openResourceInTemplate:(id)sender;
- (void)openResourceUsingTemplate:(NSString *)templateName;
- (IBAction)openResourceAsHex:(id)sender;
- (IBAction)playSound:(id)sender;
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finished;

- (IBAction)clear:(id)sender;

- (void)resourceNameWillChange:(NSNotification *)notification;
- (void)resourceIDWillChange:(NSNotification *)notification;
- (void)resourceTypeWillChange:(NSNotification *)notification;
- (void)resourceAttributesWillChange:(NSNotification *)notification;

- (BOOL)readResourceMap:(SInt16)fileRefNum;
- (BOOL)writeResourceMap:(SInt16)fileRefNum;

- (NSWindow *)mainWindow;
- (ResourceDataSource *)dataSource;
- (NSOutlineView *)outlineView;
- (NSArray *)resources;		// return the array as non-mutable

@end