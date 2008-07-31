#import "Element.h"

@interface ElementULNG : Element
{
	UInt32 value;
}

- (void)setValue:(UInt32)v;
- (UInt32)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
