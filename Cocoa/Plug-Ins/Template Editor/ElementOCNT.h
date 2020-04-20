#import "Element.h"

@interface ElementOCNT : Element
@property UInt32 value;
@property (strong) NSMutableArray *entries;

- (BOOL)countFromZero;

- (void)addEntry:(Element *)entry after:(Element *)after;
- (void)removeEntry:(Element *)entry;

@end
