#import <Cocoa/Cocoa.h>

@interface ResourceNameCell : NSTextFieldCell
@property BOOL drawImage;
@property (retain, nonatomic) NSImage *image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
