#import "Element.h"

@interface ElementFBYT : Element
{
	unsigned long length;
}

- (void)setLength:(unsigned long)l;
- (unsigned long)length;

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;

@end
