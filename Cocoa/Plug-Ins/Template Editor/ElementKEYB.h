#import <Cocoa/Cocoa.h>
#import "Element.h"

@interface ElementKEYB : Element
{
	NSMutableArray *subElements;
}
@property (assign) NSString *stringValue;
@property (retain) NSMutableArray *subElements;

@end

@interface ElementKEYE : Element
@end
