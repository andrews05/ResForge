#import "Element.h"

@interface ElementUWRD : Element
{
	UInt16 value;
}

- (void)setValue:(UInt16)v;
- (UInt16)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
