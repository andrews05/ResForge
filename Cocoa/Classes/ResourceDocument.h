#import <Cocoa/Cocoa.h>
#include <CoreServices/CoreServices.h>

@class CreateResourceSheetController, ResourceWindowController, ResourceDataSource, Resource;

@protocol ResKnifePlugin;

@interface ResourceDocument : NSDocument
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;

	CreateResourceSheetController	*sheetController;
	
	NSMutableDictionary	*toolbarItems;
	NSMutableArray	*resources;
	HFSUniStr255	fork;		// name of fork to save to, usually empty string (data fork) or 'RESOURCE_FORK' as returned from FSGetResourceForkName()
	BOOL			_createFork;	// file had no existing resource map when opened
}

@property OSType creator;
@property OSType type;

- (BOOL)readFork:(NSString *)forkName asStreamFromFile:(FSRef *)fileRef;
+ (NSMutableArray *)readResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeResourceMap:(ResFileRefNum)fileRefNum;
- (BOOL)writeForkStreamsToFile:(NSString *)fileName;

- (IBAction)exportResources:(id)sender;
- (void)exportResource:(Resource *)resource;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)showSelectTemplateSheet:(id)sender;
- (IBAction)openResources:(id)sender;
- (IBAction)openResourcesInTemplate:(id)sender;
- (IBAction)openResourcesAsHex:(id)sender;
- (id <ResKnifePlugin>)openResourceUsingEditor:(Resource *)resource;
- (id <ResKnifePlugin>)openResource:(Resource *)resource usingTemplate:(NSString *)templateName;
- (id <ResKnifePlugin>)openResourceAsHex:(Resource *)resource;
- (IBAction)playSound:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (void)pasteResources:(NSArray *)pastedResources;
- (IBAction)delete:(id)sender;
- (void)deleteResourcesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)deleteSelectedResources;

- (void)resourceNameWillChange:(NSNotification *)notification;
- (void)resourceIDWillChange:(NSNotification *)notification;
- (void)resourceTypeWillChange:(NSNotification *)notification;
- (void)resourceAttributesWillChange:(NSNotification *)notification;

- (NSWindow *)mainWindow;
- (ResourceDataSource *)dataSource;
- (NSOutlineView *)outlineView;
- (NSArray *)resources;                // return the array as non-mutable

- (IBAction)creatorChanged:(id)sender;
- (IBAction)typeChanged:(id)sender;
- (BOOL)setCreator:(OSType)newCreator andType:(OSType)newType;
- (IBAction)changeView:(id)sender;

@end
