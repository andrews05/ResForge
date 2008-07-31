#import "Element.h"

@interface ElementDBYT : Element
{
	SInt8 value;
}

- (void)setValue:(SInt8)v;
- (SInt8)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end

@interface ElementKBYT : ElementDBYT
@end