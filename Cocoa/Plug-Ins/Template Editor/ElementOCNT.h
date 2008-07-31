#import "Element.h"

@interface ElementOCNT : Element
{
	unsigned long value;
}

- (BOOL)countFromZero;

- (void)setValue:(unsigned long)v;
- (unsigned long)value;

- (void)increment;
- (void)decrement;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
