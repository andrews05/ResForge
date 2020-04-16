#import "Element.h"

@interface ElementHEXD : Element
@property (copy) NSData *value;
@property (unsafe_unretained) NSString *stringValue;
@property UInt32 length;
@property int lengthBytes;
@property BOOL skipLengthBytes;

@end
