#import "Element.h"

@interface ElementDWRD : Element
{
	SInt16 value;
}
@property SInt16 value;
@property (assign) NSString *stringValue;

@end

@interface ElementKWRD : ElementDWRD
@end
