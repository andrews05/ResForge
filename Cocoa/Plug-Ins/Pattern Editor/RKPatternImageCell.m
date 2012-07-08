//
//  RKPatternImageCell.m
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-8.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import "RKPatternImageCell.h"

@implementation RKPatternImageCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	NSColor *pattern = [NSColor colorWithPatternImage:[self image]];
	NSPoint phasePoint = [controlView convertPoint:(NSPoint){ .x = 0.0, .y = cellFrame.origin.y } toView:nil];
	[[NSGraphicsContext currentContext] setPatternPhase:phasePoint];
	[pattern set];
	NSRectFill(NSInsetRect(cellFrame, 1.0, 1.0));
}

@end
