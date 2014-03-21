#import <Cocoa/Cocoa.h>
#include <CoreServices/CoreServices.h>

@class CreateResourceSheetController, ResourceWindowController, ResourceDataSource, Resource;

@protocol ResKnifePluginProtocol;

@interface ResourceDocument : NSDocument <NSToolbarDelegate>
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;

	CreateResourceSheetController	*sheetController;
	
	NSMutableArray	*resources;
	HFSUniStr255	fork;		// name of fork to save to, usually empty string (data fork) or 'RESOURCE_FORK' as returned from FSGetResourceForkName()
	BOOL			_createFork;	// file had no existing resource map when opened
}

@property OSType creator;
@property OSType type;
@property (weak) IBOutlet NSView *viewToolbarView;

- (BOOL)readFork:(NSString *)forkName asStreamFromFile:(FSRef *)fileRef;
- (BOOL)readResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeForkStreamsToFile:(NSString *)fileName;

- (IBAction)exportResources:(id)sender;
- (void)exportResource:(Resource *)resource;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)showSelectTemplateSheet:(id)sender;
- (IBAction)openResources:(id)sender;
- (IBAction)openResourcesInTemplate:(id)sender;
- (IBAction)openResourcesAsHex:(id)sender;
- (id <ResKnifePluginProtocol>)openResourceUsingEditor:(Resource *)resource;
- (id <ResKnifePluginProtocol>)openResource:(Resource *)resource usingTemplate:(NSString *)templateName;
- (id <ResKnifePluginProtocol>)openResourceAsHex:(Resource *)resource;
- (IBAction)playSound:(id)sender;
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finished;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (void)pasteResources:(NSArray *)pastedResources;
- (IBAction)clear:(id)sender;
- (void)deleteResourcesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)deleteSelectedResources;

- (void)resourceNameWillChange:(NSNotification *)notification;
- (void)resourceIDWillChange:(NSNotification *)notification;
- (void)resourceTypeWillChange:(NSNotification *)notification;
- (void)resourceAttributesWillChange:(NSNotification *)notification;

- (NSWindow *)mainWindow;
- (ResourceDataSource *)dataSource;
- (NSOutlineView *)outlineView;
- (NSArray *)resources;		// return the array as non-mutable

- (IBAction)creatorChanged:(id)sender;
- (IBAction)typeChanged:(id)sender;
- (BOOL)setCreator:(OSType)newCreator andType:(OSType)newType;

@end
