#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

enum Attributes
{
	changedBox = 0,
	preloadBox,
	protectedBox,
	lockedBox,
	purgableBox,
	systemHeapBox
};

@interface InfoWindowController : NSWindowController
{
    IBOutlet NSMatrix 		*attributesMatrix;
    IBOutlet NSImageView	*iconView;
    IBOutlet NSTextField	*nameView;
    IBOutlet NSTextField	*resIDView;
    IBOutlet NSTextField	*typeView;
	
@private
	ResourceDocument		*currentDocument;
	Resource				*selectedResource;
}

- (void)updateInfoWindow;
- (void)setMainWindow:(NSWindow *)mainWindow;
- (IBAction)attributesChanged:(id)sender;

+ (id)sharedInfoWindowController;

@end
