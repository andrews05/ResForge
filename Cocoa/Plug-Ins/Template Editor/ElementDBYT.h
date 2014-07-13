#import "Element.h"

@interface ElementDBYT : Element
@property SInt8 value;
@property (unsafe_unretained) NSString *stringValue;

@end

@interface ElementKBYT : ElementDBYT
@end
