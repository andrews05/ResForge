#import "Element.h"

@interface ElementDBYT : Element
{
	SInt8 value;
}
@property SInt8 value;
@property (assign) NSString *stringValue;

@end

@interface ElementKBYT : ElementDBYT
@end
