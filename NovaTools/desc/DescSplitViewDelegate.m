#import "DescSplitViewDelegate.h"

@implementation DescSplitViewDelegate
/*
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	
}
*/
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
	return proposedCoord < 20.0? 20.0 : proposedCoord;
}
/*
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedCoord ofSubviewAt:(int)offset
{
	
}

- (void)splitViewWillResizeSubviews:(NSNotification *)notification
{
	
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

- (float)splitView:(NSSplitView *)splitView constrainSplitPosition:(float)proposedPosition ofSubviewAt:(int)index
{
	
}
*/
@end