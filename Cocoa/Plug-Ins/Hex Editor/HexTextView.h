#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"
#import "HexWindowController.h"

@interface HexTextView : NSTextView
{
}
- (void)editData:(NSMutableData *)data replaceBytesInRange:(NSRange)range withData:(NSData *)newData;
@end

@interface NSTextView (HexTextView)
- (void)swapForHexTextView;
@end