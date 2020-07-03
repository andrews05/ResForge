#import <Cocoa/Cocoa.h>

@class ResourceDocument, Resource;

extern NSString *DocumentInfoWillChangeNotification;
extern NSString *DocumentInfoDidChangeNotification;

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
    
    IBOutlet NSTextField    *rType;
    IBOutlet NSTextField    *rID;
    IBOutlet NSTextField    *rSize;
	
@private
	ResourceDocument		*currentDocument;
	Resource				*selectedResource;
}

+ (id)sharedInfoWindowController;

@end

@interface NSWindowController (InfoWindowAdditions)

/*!	@method	resource
	@discussion	Your plug-in should override this method to return the primary resource it's editing. Default implementation returns nil.
*/
- (Resource *)resource;

@end
