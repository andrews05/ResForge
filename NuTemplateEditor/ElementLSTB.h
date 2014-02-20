#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementLSTE;
@class ElementOCNT;

@interface ElementLSTB : Element
{
	NSMutableArray *subElements;
	ElementLSTB *groupElementTemplate;	// TMPL equivalent of self, for cloning
	ElementOCNT *countElement;			// Our "list counter" element.
}

- (void)readDataForElements:(TemplateStream *)stream;
- (IBAction)createListEntry:(id)sender;

- (void)setSubElements:(NSMutableArray *)a;
- (NSMutableArray *)subElements;

- (void)setGroupElementTemplate:(ElementLSTB *)e;
- (ElementLSTB *)groupElementTemplate;

- (void)setCountElement:(ElementOCNT *)e;
- (ElementOCNT *)countElement;

@end
