#import <Cocoa/Cocoa.h>
#import "AttributesFormatter.h"

@class Resource;

@interface OutlineViewDelegate : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
	IBOutlet NSWindow				*window;
	IBOutlet NSOutlineView			*outlineView;
	IBOutlet NSFormatter			*sizeFormatter;
	IBOutlet AttributesFormatter 	*attributesFormatter;
}

@end

@interface RKOutlineView : NSOutlineView

@end
