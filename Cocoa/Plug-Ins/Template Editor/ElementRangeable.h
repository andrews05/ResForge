#import "ElementKeyable.h"
#import "ElementCASR.h"

// Abstract Element subclass that handles CASR elements
@interface ElementRangeable : ElementKeyable
@property BOOL isRanged;
@property int displayValue;
@property ElementCASR *currentCase;

@end
