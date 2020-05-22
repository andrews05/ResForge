#import "RKDocumentController.h"
#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"

@implementation RKDocumentController

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	// set-up open panel (this happens every time, but no harm done)
	ApplicationDelegate *appDelegate = [NSApp delegate];
	OpenPanelDelegate *openPanelDelegate = appDelegate.openPanelDelegate;
    openPanelDelegate.forkIndex = 0;
	openPanel.delegate = openPanelDelegate;
    openPanel.accessoryView = openPanelDelegate.openPanelAccessoryView;
	openPanel.treatsFilePackagesAsDirectories = YES;
	
	// run panel
	NSInteger button = [super runModalOpenPanel:openPanel forTypes:extensions];
	if (button == NSOKButton)
		openPanelDelegate.readOpenPanelForFork = YES;
	return button;
}

@end
