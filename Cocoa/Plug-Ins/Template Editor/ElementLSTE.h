#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementOCNT;
@class ElementLSTB;
@interface ElementLSTE : Element
{
	ElementLSTB *groupElementTemplate;	// The item of which we're to create a copy.
	ElementOCNT *__weak countElement;			// The "counter" element if we're the end of an LSTC list.
	BOOL writesZeroByte;				// Write a terminating zero-byte when writing out this item (used by LSTZ).
}
@property (weak) NSString *stringValue;
@property BOOL writesZeroByte;
@property (strong) ElementLSTB *groupElementTemplate;
@property (weak) ElementOCNT *countElement;

- (IBAction)createListEntry:(id)sender;

@end
