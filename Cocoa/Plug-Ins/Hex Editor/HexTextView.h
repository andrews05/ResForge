#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexWindowController.h"

@interface HexTextView : NSTextView
{
}
- (void)pasteAsASCII:(id)sender;
- (void)pasteAsHex:(id)sender;
- (void)pasteAsUnicode:(id)sender;
- (void)editData:(NSData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newData;
@end

@interface NSTextView (HexTextView)
- (void)swapForHexTextView;
@end