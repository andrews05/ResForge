#import <Cocoa/Cocoa.h>

@interface ResourceNameCell : NSTextFieldCell
@property BOOL drawImage;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
