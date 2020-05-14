#import "RKDocumentController.h"
#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"

@implementation RKDocumentController

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	// set-up open panel (this happens every time, but no harm done)
	ApplicationDelegate *appDelegate = [NSApp delegate];
	OpenPanelDelegate *openPanelDelegate = [appDelegate openPanelDelegate];
	[openPanel setDelegate:openPanelDelegate];
	[openPanel setAccessoryView:openPanelDelegate.openPanelAccessoryView];
	[openPanel setAllowsOtherFileTypes:YES];
	[openPanel setTreatsFilePackagesAsDirectories:YES];
	
	// run panel
	NSInteger button = [super runModalOpenPanel:openPanel forTypes:extensions];
	if(button == NSOKButton)
		[openPanelDelegate setReadOpenPanelForFork:YES];
	return button;
}

@end
