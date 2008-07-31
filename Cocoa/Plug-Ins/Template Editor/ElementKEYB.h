#import <Cocoa/Cocoa.h>
#import "Element.h"

@interface ElementKEYB : Element
{
	NSMutableArray *subElements;
}

- (void)setSubElements:(NSMutableArray *)a;
- (NSMutableArray *)subElements;

@end

@interface ElementKEYE : Element
@end
