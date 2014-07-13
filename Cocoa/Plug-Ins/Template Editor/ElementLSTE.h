#import <Cocoa/Cocoa.h>
#import "Element.h"

@class ElementOCNT;
@class ElementLSTB;
@interface ElementLSTE : Element
@property (unsafe_unretained) NSString *stringValue;
@property BOOL writesZeroByte;							// Write a terminating zero-byte when writing out this item (used by LSTZ).
@property (strong) ElementLSTB *groupElementTemplate;	// The item of which we're to create a copy.
@property (weak) ElementOCNT *countElement;				// The "counter" element if we're the end of an LSTC list.

- (IBAction)createListEntry:(id)sender;

@end
