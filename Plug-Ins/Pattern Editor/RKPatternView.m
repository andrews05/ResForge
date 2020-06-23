//
//  RKPatternView.m
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-8.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import "RKPatternView.h"

@implementation RKPatternView
@synthesize scale;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
	[super drawRect:dirtyRect];
}

- (CGFloat)scale
{
	return scale;
}

- (void)setScale:(CGFloat)newScale
{
	scale = newScale;
	[self setNeedsDisplay:YES];
}

@end
