#import "Element.h"

@interface ElementHEXD : Element
{
	NSData *value;
}
@property (copy) NSData *value;
@property (weak) NSString *stringValue;

@end
