#import <Cocoa/Cocoa.h>

#import "ResKnifeResourceProtocol.h"

@class HexWindowController, HexTextView, AsciiTextView;

@interface HexEditorDelegate : NSObject
{
	IBOutlet HexWindowController *controller;
	IBOutlet NSTextView		*offset;
	IBOutlet HexTextView	*hex;
	IBOutlet AsciiTextView	*ascii;
	IBOutlet NSTextField	*message;
	
	BOOL		editedLow;
	NSRange		rangeForUserTextChange;
}

/* REMOVE THESE WHEN I.B. IS FIXED */
- (void)setHex:(id)newView;
- (void)setAscii:(id)newView;
/* END REMOVE MARKER */

- (void)viewDidScroll:(NSNotification *)notification;
- (NSString *)offsetRepresentation:(NSData *)data;

- (HexWindowController *)controller;
- (NSTextView *)hex;
- (NSTextView *)ascii;

- (BOOL)editedLow;
- (void)setEditedLow:(BOOL)flag;
- (NSRange)rangeForUserTextChange;

@end
