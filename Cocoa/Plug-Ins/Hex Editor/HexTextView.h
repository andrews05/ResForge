#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexWindowController.h"

@interface HexTextView : NSTextView
{
}
- (IBAction)pasteAsASCII:(id)sender;
- (IBAction)pasteAsHex:(id)sender;
- (IBAction)pasteAsUnicode:(id)sender;
- (void)editData:(NSData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newData;
@end

@interface NSTextView (HexTextView)
- (void)swapForHexTextView;
@end