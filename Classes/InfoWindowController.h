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
	IBOutlet NSTextField	*creator;
    IBOutlet NSTextField    *type;
    IBOutlet NSTextField    *dataSize;
    IBOutlet NSTextField    *rsrcSize;
	
@private
	ResourceDocument		*currentDocument;
	Resource				*selectedResource;
}

- (void)updateInfoWindow;
- (void)setMainWindow:(NSWindow *)mainWindow;
- (IBAction)attributesChanged:(id)sender;
- (IBAction)nameDidChange:(id)sender;
- (void)resourceAttributesDidChange:(NSNotification *)notification;
- (void)documentInfoDidChange:(NSNotification *)notification;

+ (id)sharedInfoWindowController;

@end

@interface NSWindowController (InfoWindowAdditions)

/*!	@method	resource
	@discussion	Your plug-in should override this method to return the primary resource it's editing. Default implementation returns nil.
*/
- (Resource *)resource;

@end
