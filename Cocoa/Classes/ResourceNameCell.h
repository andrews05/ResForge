#import <Cocoa/Cocoa.h>

@interface ResourceNameCell : NSTextFieldCell
{
	BOOL	drawImage;
	NSImage	*image;
}

- (BOOL)drawsImage;
- (void)setDrawsImage:(BOOL)flag;
- (NSImage *)image;
- (void)setImage:(NSImage *)anImage;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
