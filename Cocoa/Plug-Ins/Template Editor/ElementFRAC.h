#import "Element.h"

@interface ElementFRAC : Element
{
	Fract value;
}

- (void)setValue:(Fract)v;
- (Fract)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
