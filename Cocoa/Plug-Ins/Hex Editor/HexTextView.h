#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexWindowController.h"

@interface HexEditorTextView : NSTextView
- (IBAction)copyASCII:(id)sender;
- (IBAction)copyHex:(id)sender;
- (IBAction)pasteAsASCII:(id)sender;
- (IBAction)pasteAsHex:(id)sender;
- (IBAction)pasteAsUnicode:(id)sender;
- (IBAction)clear:(id)sender;
- (void)editData:(NSData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newData;
@end

@interface HexTextView : HexEditorTextView
@end

@interface AsciiTextView : HexEditorTextView
@end
