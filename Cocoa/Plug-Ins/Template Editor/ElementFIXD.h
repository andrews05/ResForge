#import "Element.h"

@interface ElementFIXD : Element
{
	Fixed value;
}

- (void)setValue:(Fixed)v;
- (Fixed)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
