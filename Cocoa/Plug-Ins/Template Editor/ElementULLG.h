#import "Element.h"

@interface ElementULLG : Element
{
	UInt64 value;
}

- (void)setValue:(UInt64)v;
- (UInt64)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
