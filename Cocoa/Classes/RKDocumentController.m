#import "RKDocumentController.h"
#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"

@implementation RKDocumentController

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	// set-up open panel (this happens every time, but no harm done)
	ApplicationDelegate *appDelegate = [NSApp delegate];
	OpenPanelDelegate *openPanelDelegate = [appDelegate openPanelDelegate];
	NSView *openPanelAccessoryView = [openPanelDelegate openPanelAccessoryView];
	[openPanel setDelegate:openPanelDelegate];
	[openPanel setAccessoryView:openPanelAccessoryView];
	[openPanel setAllowsOtherFileTypes:YES];
	[openPanel setTreatsFilePackagesAsDirectories:YES];
	[openPanelAccessoryView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	
	// run panel
	int button = [super runModalOpenPanel:openPanel forTypes:extensions];
	if(button == NSOKButton)
		[openPanelDelegate setReadOpenPanelForFork:YES];
	return button;
}

@end
