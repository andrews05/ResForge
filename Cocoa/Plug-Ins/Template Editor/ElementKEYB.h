#import <Cocoa/Cocoa.h>
#import "Element.h"

@interface ElementKEYB : Element
{
	NSMutableArray *subElements;
}
@property (weak) NSString *stringValue;
@property (strong) NSMutableArray *subElements;

@end

@interface ElementKEYE : Element
@end
