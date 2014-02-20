#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementOCNT;
@class ElementLSTB;
@interface ElementLSTE : Element
{
	ElementLSTB *groupElementTemplate;	// The item of which we're to create a copy.
	ElementOCNT *countElement;			// The "counter" element if we're the end of an LSTC list.
	BOOL writesZeroByte;				// Write a terminating zero-byte when writing out this item (used by LSTZ).
}

- (IBAction)createListEntry:(id)sender;

- (void)setWritesZeroByte:(BOOL)n;
- (BOOL)writesZeroByte;

- (void)setGroupElementTemplate:(ElementLSTB *)e;
- (ElementLSTB *)groupElementTemplate;

- (void)setCountElement:(ElementOCNT *)e;
- (ElementOCNT *)countElement;

@end
