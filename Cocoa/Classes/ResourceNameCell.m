#import "ResourceNameCell.h"

@implementation ResourceNameCell
@synthesize image;
@synthesize drawImage;

- (instancetype)init
{
	if (self = [super init]) {
		self.wraps = NO;
		drawImage = YES;
		image = nil;
	}
	return self;
}

- copyWithZone:(NSZone *)zone
{
	ResourceNameCell *cell = nil;
	if ((cell = [super copyWithZone:zone])) {
		cell.image = image;
	}
	return cell;
}

- (void)setImage:(NSImage *)newImage
{
	if(image != newImage)
	{
		// save image and set to 16x16 pixels
		image = newImage;
		[image setSize:NSMakeSize(16,16)];
	}
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
	if(image != nil && drawImage == YES)
	{
		// center image vertically in frame, offset right by three
		NSRect imageFrame;
		imageFrame.size = [image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += 3;
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		return imageFrame;
	}
	else return NSZeroRect;
}

- (void)editWithFrame:(NSRect)cellFrame inView:(NSView *)controlView editor:(NSText *)textObject delegate:(id)delegateObject event:(NSEvent *)theEvent
{
	if(drawImage == YES)
	{
		// split cell frame into two, pass the text part to the superclass
		NSRect textFrame, imageFrame;
		NSDivideRect(cellFrame, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
		[super editWithFrame:textFrame inView:controlView editor:textObject delegate:delegateObject event:theEvent];
	}
	else
	{
		[super editWithFrame:cellFrame inView:controlView editor:textObject delegate:delegateObject event:theEvent];
	}
}

- (void)selectWithFrame:(NSRect)cellFrame inView:(NSView *)controlView editor:(NSText *)textObject delegate:(id)delegateObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	if(drawImage == YES)
	{
		// split cell frame into two, pass the text part to the superclass
		NSRect textFrame, imageFrame;
		NSDivideRect(cellFrame, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
		[super selectWithFrame:textFrame inView:controlView editor:textObject delegate:delegateObject start:selStart length:selLength];
	}
	else
	{
		[super selectWithFrame:cellFrame inView:controlView editor:textObject delegate:delegateObject start:selStart length:selLength];
	}
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if(image != nil && drawImage == YES)
	{
		NSRect imageFrame;
		NSSize imageSize = [image size];
		
		// get image frame
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		if([self drawsBackground] && ![self isHighlighted] /* ![self cellAttribute:NSCellHighlighted] */)
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;
		
		// center vertically
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2.0);

		NSAffineTransform *t = nil;

		if ([controlView isFlipped]) {
			t = [NSAffineTransform transform];
			[t translateXBy:0.0 yBy:cellFrame.origin.y * 2.0 + cellFrame.size.height];
			[t scaleXBy:1.0 yBy:-1.0];
			[t concat];
		}

		// draw image
		[image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

		if ([controlView isFlipped])
			[t concat];
	}
	
	// get the superclass to draw the text stuff
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	if(drawImage == YES)
		cellSize.width += (image? [image size].width:0) + 3;
	return cellSize;
}

@end
