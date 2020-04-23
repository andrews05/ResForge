#import "Element.h"

@class ElementOCNT;

@interface ElementLSTB : Element
@property (strong) NSMutableArray *subElements;
@property (strong) NSMutableArray *entries;
@property (weak) ElementOCNT *countElement;		// Our "list counter" element.
@property (weak) ElementLSTB *tail;
@property BOOL zeroTerminated;

- (BOOL)createListEntry;
- (BOOL)removeListEntry;

@end
