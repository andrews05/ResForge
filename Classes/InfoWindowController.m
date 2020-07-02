#import "InfoWindowController.h"
@import CoreServices.CarbonCore.Resources;
#import "ResourceDocument.h"
#import "Resource.h"
#import "ApplicationDelegate.h"
#import "NSOutlineView-SelectedItems.h"

@implementation InfoWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// set window to only accept key when editing text boxes
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
	
    [self setMainWindow:NSApp.mainWindow];
	[self updateInfoWindow];
	
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(selectedResourceChanged:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resourceAttributesDidChange:) name:ResourceAttributesDidChangeNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(documentInfoDidChange:) name:DocumentInfoDidChangeNotification object:nil];
}

/*!
@method		updateInfoWindow
@updated	2003-11-06 NGS:	Fixed creator/type handling.
@updated	2003-10-26 NGS:	Now asks app delegate for icon instead of NSWorkspace.
@updated	2003-10-26 NGS:	Improved document name & icon display.
*/

- (void)updateInfoWindow
{
    nameView.editable = selectedResource != nil;
    nameView.bezeled = selectedResource != nil;
	
	if (selectedResource) {
		// set UI values
        self.window.title = NSLocalizedString(@"Resource Info", nil);
        nameView.stringValue = selectedResource.name;
        iconView.image = [(ApplicationDelegate *)[NSApp delegate] iconForResourceType:selectedResource.type];
//		[[attributesMatrix cellAtRow:changedBox column:0]		setState:selectedResource.attributes & resChanged];
//		[[attributesMatrix cellAtRow:preloadBox column:0]		setState:selectedResource.attributes & resPreload];
//		[[attributesMatrix cellAtRow:protectedBox column:0]		setState:selectedResource.attributes & resProtected];
//		[[attributesMatrix cellAtRow:lockedBox column:0]		setState:selectedResource.attributes & resLocked];
//		[[attributesMatrix cellAtRow:purgableBox column:0]		setState:selectedResource.attributes & resPurgeable];
//		[[attributesMatrix cellAtRow:systemHeapBox column:0]	setState:selectedResource.attributes & resSysHeap];
//
//		// swap box
//        placeholderView.contentView = resourceView;
        rType.stringValue = GetNSStringFromOSType(selectedResource.type);
        rID.intValue = selectedResource.resID;
        rSize.integerValue = selectedResource.data.length;
        placeholderView.contentView = resourcePropsView;
	} else if (currentDocument) {
		// get sizes of forks as they are on disk
		NSInteger dataLogicalSize = 0, rsrcLogicalSize = 0;
		
		// set info window elements to correct values
        self.window.title = NSLocalizedString(@"Document Info", nil);
		if (currentDocument.fileURL) {
            iconView.image = [[NSWorkspace sharedWorkspace] iconForFile:currentDocument.fileURL.path];
            nameView.stringValue = currentDocument.fileURL.lastPathComponent;
            NSNumber *dataSize, *totalSize;
            [currentDocument.fileURL getResourceValue:&dataSize forKey:NSURLFileSizeKey error:nil];
            [currentDocument.fileURL getResourceValue:&totalSize forKey:NSURLTotalFileSizeKey error:nil];
            dataLogicalSize = dataSize.integerValue;
            rsrcLogicalSize = totalSize.integerValue - dataLogicalSize;
		} else {
            iconView.image = [NSImage imageNamed:@"Resource file"];
            nameView.stringValue = currentDocument.displayName;
		}
		
        creator.stringValue = GetNSStringFromOSType(currentDocument.creator);
        type.stringValue = GetNSStringFromOSType(currentDocument.type);
        dataSize.integerValue = dataLogicalSize;
		rsrcSize.integerValue = rsrcLogicalSize;
		
		// swap box
        placeholderView.contentView = documentView;
	} else {
        iconView.image = nil;
        nameView.stringValue = @"";
        placeholderView.contentView = nil;
	}
}

- (void)setMainWindow:(NSWindow *)mainWindow
{
    NSWindowController *controller = mainWindow.windowController;
	
    if ([controller.document isKindOfClass:ResourceDocument.class])
        currentDocument = controller.document;
	else currentDocument = nil;
	
    if (currentDocument) {
        [self setSelectedResource:currentDocument.outlineView.selectedItem];
    } else {
        [self setSelectedResource:controller.resource];
    }
}

- (void)setSelectedResource:(Resource *)resource
{
    if ([resource isKindOfClass:Resource.class]) {
        selectedResource = resource;
    } else {
        selectedResource = nil;
    }
    [self updateInfoWindow];
}

- (void)mainWindowChanged:(NSNotification *)notification
{
    [self setMainWindow:notification.object];
}

- (void)selectedResourceChanged:(NSNotification *)notification
{
    if (![nameView.stringValue isEqualToString:selectedResource.name])
		[self nameDidChange:nameView];
    [self setSelectedResource:[notification.object selectedItem]];
}

- (void)documentInfoDidChange:(NSNotification *)notification
{
    currentDocument = notification.object[@"NSDocument"];
	[self updateInfoWindow];
}

- (IBAction)attributesChanged:(id)sender
{
	short attr = (short)(0x0001 << ([sender selectedRow]+1));
    short number = (selectedResource.attributes ^ attr);
	[selectedResource setAttributes:number];
}

- (IBAction)nameDidChange:(id)sender
{
    [selectedResource setName:nameView.stringValue];
}

- (void)resourceAttributesDidChange:(NSNotification *)notification;
{
	[self updateInfoWindow];
}

+ (id)sharedInfoWindowController
{
	static InfoWindowController *sharedInfoWindowController = nil;
	if (!sharedInfoWindowController)
		sharedInfoWindowController = [[InfoWindowController allocWithZone:nil] initWithWindowNibName:@"InfoWindow"];
	return sharedInfoWindowController;
}

@end

@implementation NSWindowController (InfoWindowAdditions)

- (Resource *)resource
{
	return nil;
}

@end
