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
@property (assign) NSString *stringValue;
@property (retain) NSMutableArray *subElements;
@property (assign) ElementLSTB *groupElementTemplate;
@property (assign) ElementOCNT *countElement;

- (void)readDataForElements:(TemplateStream *)stream;
- (IBAction)createListEntry:(id)sender;

@end
