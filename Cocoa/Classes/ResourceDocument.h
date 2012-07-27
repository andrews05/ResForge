#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework

@class CreateResourceSheetController, ResourceWindowController, ResourceDataSource, Resource;

@protocol ResKnifePluginProtocol;

@interface ResourceDocument : NSDocument <NSToolbarDelegate>
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;
	CreateResourceSheetController	*sheetController;
	
	NSMutableDictionary	*toolbarItems;
	NSMutableArray	*resources;
	HFSUniStr255	*fork;		// name of fork to save to, usually empty string (data fork) or 'RESOURCE_FORK' as returned from FSGetResourceForkName()
	NSData			*creator;
	NSData			*type;
	BOOL			_createFork;	// file had no existing resource map when opened
}

- (BOOL)readFork:(NSString *)forkName asStreamFromFile:(FSRef *)fileRef;
- (BOOL)readResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeForkStreamsToFile:(NSString *)fileName;

- (IBAction)exportResources:(id)sender;
- (void)exportResource:(Resource *)resource;
- (void)exportPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)setupToolbar:(NSWindowController *)windowController;

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
- (void)overwritePasteSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
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

- (NSData *)creator;
- (NSData *)type;
- (IBAction)creatorChanged:(id)sender;
- (IBAction)typeChanged:(id)sender;
- (BOOL)setCreator:(NSData *)newCreator;
- (BOOL)setType:(NSData *)newType;
- (BOOL)setCreator:(NSData *)newCreator andType:(NSData *)newType;

@end
