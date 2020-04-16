#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementLSTE;
@class ElementOCNT;

@interface ElementLSTB : Element
@property (unsafe_unretained) NSString *stringValue;
@property (strong) NSMutableArray *subElements;
@property (weak) ElementLSTB *groupElementTemplate;	// TMPL equivalent of self, for cloning
@property (weak) ElementOCNT *countElement;			// Our "list counter" element.

- (void)readDataForElements:(TemplateStream *)stream;
- (BOOL)createListEntry;
- (BOOL)removeListEntry;

@end
