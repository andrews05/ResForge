#import <Cocoa/Cocoa.h>
#import "NameFormatter.h"
#import "SizeFormatter.h"
#import "AttributesFormatter.h"

@class Resource;

@interface OutlineViewDelegate : NSObject
{
	IBOutlet NSWindow		*window;
	IBOutlet NameFormatter	*nameFormatter;
	IBOutlet SizeFormatter	*sizeFormatter;
	IBOutlet AttributesFormatter *attributesFormatter;
}

int compareResourcesAscending( Resource *r1, Resource *r2, void *context );
int compareResourcesDescending( Resource *r1, Resource *r2, void *context );

@end
