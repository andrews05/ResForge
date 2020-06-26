#import <Cocoa/Cocoa.h>
#include <CoreServices/CoreServices.h>

@class CreateResourceSheetController, ResourceWindowController, ResourceDataSource, Resource;

@protocol ResKnifePlugin;

typedef enum {
    kFormatClassic,
    kFormatExtended,
    kFormatRez
} FileFormat;

@interface ResourceDocument : NSDocument
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;

	CreateResourceSheetController	*sheetController;
}
@property NSMutableArray *resources;
@property NSMutableDictionary *editorWindows;
@property NSString *fork; // name of fork to save to, usually empty string (data fork) or 'rsrc'
@property FileFormat format;
@property OSType creator;
@property OSType type;

+ (NSMutableArray *)readResourceMap:(NSURL *)url document:(ResourceDocument *)document;

- (IBAction)exportResources:(id)sender;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)showSelectTemplateSheet:(id)sender;
- (IBAction)openResources:(id)sender;
- (IBAction)openResourcesInTemplate:(id)sender;
- (IBAction)openResourcesAsHex:(id)sender;
- (id <ResKnifePlugin>)openResourceUsingEditor:(Resource *)resource;
- (id <ResKnifePlugin>)openResource:(Resource *)resource usingTemplate:(NSString *)templateName;
- (id <ResKnifePlugin>)openResourceAsHex:(Resource *)resource;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (void)pasteResources:(NSArray *)pastedResources;
- (IBAction)delete:(id)sender;
- (void)deleteSelectedResources;

- (NSWindow *)mainWindow;
- (ResourceDataSource *)dataSource;
- (NSOutlineView *)outlineView;

- (IBAction)creatorChanged:(id)sender;
- (IBAction)typeChanged:(id)sender;
- (IBAction)changeView:(id)sender;

@end
