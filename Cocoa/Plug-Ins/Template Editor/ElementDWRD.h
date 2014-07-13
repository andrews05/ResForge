#import "Element.h"

@interface ElementDWRD : Element
@property SInt16 value;
@property (unsafe_unretained) NSString *stringValue;

@end

@interface ElementKWRD : ElementDWRD
@end
