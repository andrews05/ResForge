#import <Cocoa/Cocoa.h>
#import "ResourceFile.h"

static inline NSString *GetNSStringFromOSType(OSType theType)
{
    return CFBridgingRelease(UTCreateStringForOSType(theType));
}

static inline OSType GetOSTypeFromNSString(NSString *theString)
{
    return UTGetOSTypeFromString((__bridge CFStringRef)theString);
}

@class CreateResourceController, ResourceWindowController, ResourceDataSource, Resource, PluginManager;

@protocol ResKnifePlugin;

@interface ResourceDocument : NSDocument
{
	IBOutlet ResourceDataSource		*dataSource;
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSOutlineView			*outlineView;

	CreateResourceController	*sheetController;
}
@property NSArray *resources;
@property PluginManager *registry;
@property NSString *fork; // name of fork to save to, usually empty string (data fork) or 'rsrc'
@property ResourceFileFormat format;
@property OSType creator;
@property OSType type;

- (IBAction)exportResources:(id)sender;

- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)showSelectTemplateSheet:(id)sender;
- (IBAction)openResources:(id)sender;
- (IBAction)openResourcesInTemplate:(id)sender;
- (IBAction)openResourcesAsHex:(id)sender;

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
