#import "Element.h"

@interface ElementDATE : Element
@property UInt32 seconds; // seconds since 1 Jan 1904
@property (unsafe_unretained) NSDate *value;

@end
