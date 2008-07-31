#import "Element.h"

@interface ElementHEXD : Element
{
	NSData *value;
}
- (void)setValue:(NSData *)d;
- (NSData *)value;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
