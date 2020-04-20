#import "Element.h"

@interface ElementHEXD : Element
@property (copy) NSData *data;
@property (unsafe_unretained) NSString *value;
@property UInt32 length;
@property int lengthBytes;
@property BOOL skipLengthBytes;

@end
