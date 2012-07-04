//
//  PNGWindowController.m
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-4.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import "PNGWindowController.h"

@interface PNGWindowController ()

@end

@implementation PNGWindowController
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
	image = [[NSImage alloc] initWithData:data];
	[imageView setImage:image];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (void)dealloc {
	[image release];
	[resource release];
	[super dealloc];
}

- (id)initWithResource:(id <ResKnifeResourceProtocol>)inResource {
	if (self = [self initWithWindowNibName:@"PNGWindowController"]) {
		resource = [inResource retain];
		[self window];
	}
	
	return self;
}

- (void)resourceDataDidChange:(NSNotification *)note {
	NSData *data = [resource data];
	[image release];
	image = [[NSImage alloc] initWithData:data];
	[imageView setImage:image];
}

@end
