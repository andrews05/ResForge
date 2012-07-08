//
//  PatternWindowController.m
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-7.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import "PatternWindowController.h"
#import "ResKnifeResourceProtocol.h"

@interface PatternWindowController ()

@end

@implementation PatternWindowController
@synthesize imageView;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{    
	[super windowDidLoad];
	
	// set the window's title
	[[self window] setTitle:[resource defaultWindowTitle]];
	
	NSData *data = [resource data];
	
	unsigned char *planes[1] = { 0 };
	planes[0] = (unsigned char *)[data bytes];
	
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes pixelsWide:8 pixelsHigh:8 bitsPerSample:1 samplesPerPixel:1 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedWhiteColorSpace bytesPerRow:1 bitsPerPixel:1];
	
	for (NSUInteger i = 0; i < 8; ++i)
		[rep bitmapData][i] ^= 0xff;
	
	image = [[NSImage alloc] init];
	[image addRepresentation:rep];
	[imageView setImage:image];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (id)initWithResource:(id <ResKnifeResourceProtocol>)inResource {
	if (self = [self initWithWindowNibName:@"PatternWindowController"]) {
		resource = [inResource retain];
		[self window];
	}
	
	return self;
}

- (void)dealloc {
	[resource release];
	[super dealloc];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

@end
