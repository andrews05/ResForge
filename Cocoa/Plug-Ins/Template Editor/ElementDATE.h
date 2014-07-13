#import "Element.h"

@interface ElementDATE : Element
@property UInt32 value; // seconds since 1 Jan 1904
@property (unsafe_unretained) NSString *stringValue;

@end
