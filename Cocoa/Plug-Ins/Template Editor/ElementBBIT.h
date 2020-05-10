#import "ElementRangeable.h"

@interface ElementBBIT : ElementRangeable
@property UInt32 value;
@property unsigned int bits;
@property unsigned int position;
@property NSMutableArray<ElementBBIT *> *bitList;
@property BOOL first;

@end
