#import "ResourceNameCell.h"

@implementation ResourceNameCell

- (void)dealloc
{
	[image release];
	[super dealloc];
}

- copyWithZone:(NSZone *)zone
{
	ResourceNameCell *cell = (ResourceNameCell *)[super copyWithZone:zone];
	(* cell).image = [image retain];
	return cell;
}

- (void)setImage:(NSImage *)newImage
{
	[image release];
	image = [newImage retain];
}

- (NSImage *)image
{
	return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
	if( image != nil )
	{
		NSRect imageFrame;
		imageFrame.size = NSMakeSize( 16.0, 16.0 );	// [image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += 3;
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		return imageFrame;
	}
	else return NSZeroRect;
}

- (void)editWithFrame:(NSRect)cellFrame inView:(NSView *)controlView editor:(NSText *)textObject delegate:(id)delegateObject event:(NSEvent *)theEvent
{
	NSRect textFrame, imageFrame;
	NSDivideRect( cellFrame, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge );
	[super editWithFrame:textFrame inView:controlView editor:textObject delegate:delegateObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)cellFrame inView:(NSView *)controlView editor:(NSText *)textObject delegate:(id)delegateObject start:(int)selStart length:(int)selLength
{
	NSRect textFrame, imageFrame;
	NSDivideRect( cellFrame, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
	[super selectWithFrame:textFrame inView:controlView editor:textObject delegate:delegateObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if( image != nil )
	{
		NSRect imageFrame;
		NSSize imageSize = [image size];

		NSDivideRect( cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge );
		if( [self drawsBackground] )
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;

		if( [controlView isFlipped] )
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

//		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
		[image drawInRect:imageFrame fromRect:NSMakeRect( 0, 0, imageSize.width, imageSize.height ) operation:NSCompositeSourceOver fraction:1.0];
	}
	
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (image? [image size].width:0) + 3;
	return cellSize;
}

@end
