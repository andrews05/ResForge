#import "Element.h"

@interface ElementDLNG : Element
{
	SInt32 value;
}

- (void)setValue:(SInt32)v;
- (SInt32)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end

@interface ElementKLNG : ElementDLNG
@end
