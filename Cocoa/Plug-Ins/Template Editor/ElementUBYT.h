#import "Element.h"

@interface ElementUBYT : Element
{
	UInt8 value;
}

- (void)setValue:(UInt8)v;
- (UInt8)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
