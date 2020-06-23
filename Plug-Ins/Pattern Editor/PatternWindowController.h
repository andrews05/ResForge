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
@protocol ResKnifeResource;

@interface PatternWindowController : NSWindowController <ResKnifePlugin, NSTableViewDataSource, NSTableViewDelegate> {
	id<ResKnifeResource>	resource;
	NSMutableArray			*images;
}

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSImageView *imageView;

@end
