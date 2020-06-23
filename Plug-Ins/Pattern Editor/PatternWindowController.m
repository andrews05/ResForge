//
//  PatternWindowController.m
//  ResKnife
//
//  Created by Nate Weaver on 2012-7-7.
//  Copyright (c) 2012 Derailer. All rights reserved.
//

#import "PatternWindowController.h"
#import "ResKnifeResourceProtocol.h"

@protocol WhereIsIt
- (void)resourceDataDidChange:(NSNotification *)notification;

@end

@interface PatternWindowController ()

@end

@implementation PatternWindowController
@synthesize tableView;
@synthesize imageView;

- (instancetype)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
		images = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSImage *)imageWithPATData:(NSData *)data {
	unsigned char *oneBitData = (unsigned char *)[data bytes];
	
	// make our own grayscale rep insted of a 1-bit rep to avoid some weird drawing bugs :/
	
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:8 pixelsHigh:8 bitsPerSample:8 samplesPerPixel:1 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedWhiteColorSpace bytesPerRow:8 bitsPerPixel:8];
	
	unsigned char *grayscaleData = [rep bitmapData];
	
	for (NSUInteger i = 0; i < 8; ++i) {
		for (NSUInteger j = 0; j < 8; ++j)
			grayscaleData[i * 8 + j] = (oneBitData[i] & (1 << j)) ? 0x0 : 0xff;
	}
	
	NSImage *newImage = [[NSImage alloc] init];
	[newImage addRepresentation:rep];
	return newImage;
}

- (void)loadPAT:(id <ResKnifeResource>)inResource {
	NSData *data = [inResource data];
	[images addObject:[self imageWithPATData:data]];
}

- (void)loadPATList:(id <ResKnifeResource>)inResource {
	NSData *data = [inResource data];
	
	uint16_t numberOfPatterns;
	[data getBytes:&numberOfPatterns length:sizeof(numberOfPatterns)];
	numberOfPatterns = CFSwapInt16BigToHost(numberOfPatterns);
		
	NSUInteger loc = sizeof(numberOfPatterns);
	
	do {
		NSData *subdata = [data subdataWithRange:(NSRange){ .location = loc, .length = 8 }];
		[images addObject:[self imageWithPATData:subdata]];
	} while ((loc += 8) <= [data length] - 8);
}

- (void)windowDidLoad
{    
	[super windowDidLoad];
		
	// set the window's title
	[[self window] setTitle:[resource defaultWindowTitle]];
	
	[tableView reloadData];
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (instancetype)initWithResource:(id <ResKnifeResource>)inResource
{
	if (self = [self initWithWindowNibName:@"PatternWindowController"]) {
		resource = inResource;
		switch (resource.type) {
			case 'PAT ':// single 8x8 B&W pattern
				[self loadPAT:resource];
				break;
				
			case 'PAT#': // list of 8x8 B&W patterns
				[self loadPATList:resource];
				break;
				
			default:
				break;
		}
		[self window];
	}
	
	return self;
}


- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [images count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return images[row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSImage *image = images[[tableView selectedRow]];
	[imageView setImage:image];
}

@end
