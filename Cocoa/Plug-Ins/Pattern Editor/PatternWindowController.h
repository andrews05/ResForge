//
//  PatternWindowController.h
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-7.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ResKnifePluginProtocol.h"

@class Resource;
@protocol ResKnifeResourceProtocol;

@interface PatternWindowController : NSWindowController <ResKnifePluginProtocol> {
	NSImageView *imageView;
	id <ResKnifeResourceProtocol>	resource;
	NSImage		*image;
}

@property (assign) IBOutlet NSImageView *imageView;

@end
