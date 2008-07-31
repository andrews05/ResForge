#import "Element.h"

@interface ElementDLLG : Element
{
	SInt64 value;
}

- (void)setValue:(SInt64)v;
- (SInt64)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
