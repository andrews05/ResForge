#import <Cocoa/Cocoa.h>
#import "Element.h"

@interface ElementKEYB : Element
@property (unsafe_unretained) NSString *stringValue;
@property (strong) NSMutableArray *subElements;

@end

@interface ElementKEYE : Element
@end
