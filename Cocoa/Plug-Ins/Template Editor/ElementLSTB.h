#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementLSTE;
@class ElementOCNT;

@interface ElementLSTB : Element
{
	NSMutableArray *subElements;
	ElementLSTB *__weak groupElementTemplate;	// TMPL equivalent of self, for cloning
	ElementOCNT *__weak countElement;			// Our "list counter" element.
}
@property (weak) NSString *stringValue;
@property (strong) NSMutableArray *subElements;
@property (weak) ElementLSTB *groupElementTemplate;
@property (weak) ElementOCNT *countElement;

- (void)readDataForElements:(TemplateStream *)stream;
- (IBAction)createListEntry:(id)sender;

@end
