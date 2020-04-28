#import "Element.h"

@interface ElementBBIT : Element
@property UInt32 value;
@property unsigned int bits;
@property unsigned int position;
@property NSMutableArray<ElementBBIT *> *bitList;
@property BOOL first;

@end
