#import "Element.h"
#import "ElementOCNT.h"

@interface ElementLSTB : Element
@property (strong) ElementList *subElements;
@property (strong) NSMutableArray *entries;
@property (weak) ElementOCNT *countElement;		// Our "list counter" element.
@property (weak) ElementLSTB *tail;
@property BOOL zeroTerminated;
@property (strong) Element *singleElement;

- (BOOL)allowsCreateListEntry;
- (BOOL)allowsRemoveListEntry;
- (void)createListEntry;
- (void)removeListEntry;

@end
