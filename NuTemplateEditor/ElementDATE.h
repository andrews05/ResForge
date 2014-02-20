#import "Element.h"

@interface ElementDATE : Element
{
	// seconds since 1 Jan 1904
	UInt32 value;
}
- (UInt32)value;
- (void)setValue:(UInt32)v;
- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;
@end
