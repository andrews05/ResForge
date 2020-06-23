//
//  PNGWindowController.h
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-4.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"


@interface PNGWindowController : NSWindowController <ResKnifePlugin> {
	NSImage					*image;
	id<ResKnifeResource>	resource;
}

@property (weak) IBOutlet NSImageView *imageView;

@end
