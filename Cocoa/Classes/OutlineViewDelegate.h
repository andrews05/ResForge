#import <Cocoa/Cocoa.h>
#import "AttributesFormatter.h"

@class Resource;

@interface OutlineViewDelegate : NSObject <NSOutlineViewDataSource>
{
	IBOutlet NSWindow				*window;
	IBOutlet NSOutlineView			*outlineView;
	IBOutlet NSFormatter			*sizeFormatter;
	IBOutlet AttributesFormatter 	*attributesFormatter;
}

//int compareResourcesAscending(Resource *r1, Resource *r2, void *context);
//int compareResourcesDescending(Resource *r1, Resource *r2, void *context);

@end

@interface RKOutlineView : NSOutlineView
@end