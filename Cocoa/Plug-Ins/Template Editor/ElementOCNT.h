#import "Element.h"

@interface ElementOCNT : Element
@property UInt32 value;
@property (unsafe_unretained) NSString *stringValue;

- (BOOL)countFromZero;

- (void)increment;
- (void)decrement;

@end
