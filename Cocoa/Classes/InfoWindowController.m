#import "InfoWindowController.h"
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework, but <Carbon/CarbonCore.h> and <CarbonCore/CarbonCore.h> don't work, so I don't know what else to do
#import "ResourceDocument.h"
#import "Resource.h"

@implementation InfoWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"InfoWindow"];
	if( self ) [self setWindowFrameAutosaveName:@"Resource Info"];
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	[self setMainWindow:[NSApp mainWindow]];
	[self updateInfoWindow];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedResourceChanged:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)updateInfoWindow
{
	if( selectedResource )
	{
		[nameView setStringValue:[selectedResource name]];
		[typeView setStringValue:[selectedResource type]];
		[resIDView setStringValue:[[selectedResource resID] stringValue]];
		[[attributesMatrix cellAtRow:changedBox column:0]	setState:[[selectedResource attributes] shortValue] & resChanged];
		[[attributesMatrix cellAtRow:preloadBox column:0]	setState:[[selectedResource attributes] shortValue] & resPreload];
		[[attributesMatrix cellAtRow:protectedBox column:0]	setState:[[selectedResource attributes] shortValue] & resProtected];
		[[attributesMatrix cellAtRow:lockedBox column:0]	setState:[[selectedResource attributes] shortValue] & resLocked];
		[[attributesMatrix cellAtRow:purgableBox column:0]	setState:[[selectedResource attributes] shortValue] & resPurgeable];
		[[attributesMatrix cellAtRow:systemHeapBox column:0] setState:[[selectedResource attributes] shortValue] & resSysHeap];
	}
	else
	{
		[nameView setStringValue:@""];
		[typeView setStringValue:@""];
		[resIDView setStringValue:@""];
		[[attributesMatrix cellAtRow:changedBox column:0]	setState:NSOffState];
		[[attributesMatrix cellAtRow:preloadBox column:0]	setState:NSOffState];
		[[attributesMatrix cellAtRow:protectedBox column:0]	setState:NSOffState];
		[[attributesMatrix cellAtRow:lockedBox column:0]	setState:NSOffState];
		[[attributesMatrix cellAtRow:purgableBox column:0]	setState:NSOffState];
		[[attributesMatrix cellAtRow:systemHeapBox column:0] setState:NSOffState];
	}
}

- (void)setMainWindow:(NSWindow *)mainWindow
{
	NSWindowController *controller = [mainWindow windowController];
	
	if( [[controller document] isKindOfClass:[ResourceDocument class]] )
		currentDocument = [controller document];
	else currentDocument = nil;
	
	selectedResource = [[currentDocument outlineView] itemAtRow:[[currentDocument outlineView] selectedRow]];
	[self updateInfoWindow];
}

- (void)mainWindowChanged:(NSNotification *)notification
{
	[self setMainWindow:[notification object]];
}

- (void)selectedResourceChanged:(NSNotification *)notification
{
	selectedResource = [[notification object] itemAtRow:[[notification object] selectedRow]];
	[self updateInfoWindow];
}

- (IBAction)attributesChanged:(id)sender
{
	short attr = 0x0001 << [sender selectedRow]+1;
	short number = ([[selectedResource attributes] shortValue] ^ attr);
	[selectedResource setAttributes:[NSNumber numberWithShort:number]];
	[self updateInfoWindow];
}

+ (id)sharedInfoWindowController
{
	static InfoWindowController *sharedInfoWindowController = nil;
	
	if( !sharedInfoWindowController )
	{
		sharedInfoWindowController = [[InfoWindowController allocWithZone:[self zone]] init];
	}
	return sharedInfoWindowController;
}

@end
