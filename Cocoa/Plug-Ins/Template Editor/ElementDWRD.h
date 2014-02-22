#import "Element.h"

@interface ElementDWRD : Element
{
	SInt16 value;
}
@property SInt16 value;
@property (weak) NSString *stringValue;

@end

@interface ElementKWRD : ElementDWRD
@end
