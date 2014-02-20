#import "Element.h"

@interface ElementDWRD : Element
{
	SInt16 value;
}

- (void)setValue:(SInt16)v;
- (SInt16)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end

@interface ElementKWRD : ElementDWRD
@end
