#import <Cocoa/Cocoa.h>

@interface ResourceNameCell : NSTextFieldCell
#ifndef __LP64__
{
	BOOL	drawImage;
	NSImage	*image;
}
#endif
@property BOOL drawImage;
@property (retain, nonatomic) NSImage *image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
