#import "Element.h"

@interface ElementOCNT : Element
{
	UInt32 value;
}
@property UInt32 value;
@property (assign) NSString *stringValue;

- (BOOL)countFromZero;

- (void)increment;
- (void)decrement;

@end
