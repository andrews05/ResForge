#import <Cocoa/Cocoa.h>

@class CreateResourceController, ResourceWindowController, ResourceDataSource, Resource, EditorRegistry;

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

	CreateResourceController	*sheetController;
}
@property NSMutableArray *resources;
@property EditorRegistry *registry;
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

- (IBAction)changeView:(id)sender;

@end
