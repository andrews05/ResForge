#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

extern NSString *DocumentInfoWillChangeNotification;
extern NSString *DocumentInfoDidChangeNotification;

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
	IBOutlet NSImageView	*iconView;
	IBOutlet NSTextField	*nameView;
	
	IBOutlet NSBox			*placeholderView;
	IBOutlet NSBox			*resourceView;
	IBOutlet NSBox			*documentView;
	
	IBOutlet NSMatrix 		*attributesMatrix;
	IBOutlet NSForm			*creatorTypeView;
	
@private
	ResourceDocument		*currentDocument;
	Resource				*selectedResource;
}

- (void)updateInfoWindow;
- (void)setMainWindow:(NSWindow *)mainWindow;
- (IBAction)attributesChanged:(id)sender;
- (void)resourceAttributesDidChange:(NSNotification *)notification;

+ (id)sharedInfoWindowController;

@end
