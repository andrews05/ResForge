#import <Cocoa/Cocoa.h>
#import "NameFormatter.h"
#import "SizeFormatter.h"
#import "AttributesFormatter.h"

@interface OutlineViewDelegate : NSObject
{
	IBOutlet NSWindow		*window;
	IBOutlet NameFormatter	*nameFormatter;
	IBOutlet SizeFormatter	*sizeFormatter;
	IBOutlet AttributesFormatter *attributesFormatter;
}
@end
