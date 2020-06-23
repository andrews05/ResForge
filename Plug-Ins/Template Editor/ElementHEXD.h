#import "Element.h"

@interface ElementHEXD : Element
@property (copy) NSData *data;
@property UInt32 length;
@property int lengthBytes;
@property BOOL skipLengthBytes;

@end
