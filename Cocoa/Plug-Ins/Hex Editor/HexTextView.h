#import <Cocoa/Cocoa.h>
#import "HexEditorDelegate.h"

@interface HexTextView : NSTextView
{
}
@end

@interface NSTextView (HexTextView)

- (void)swapForHexTextView;

@end