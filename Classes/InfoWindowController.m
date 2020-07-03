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
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(propertiesDidChange:) name:ResourceDidChangeNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(propertiesDidChange:) name:DocumentInfoDidChangeNotification object:nil];
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
        
		[[attributesMatrix cellWithTag:resChanged]		setState:selectedResource.attributes & resChanged];
		[[attributesMatrix cellWithTag:resPreload]		setState:selectedResource.attributes & resPreload];
		[[attributesMatrix cellWithTag:resProtected]	setState:selectedResource.attributes & resProtected];
		[[attributesMatrix cellWithTag:resLocked]		setState:selectedResource.attributes & resLocked];
		[[attributesMatrix cellWithTag:resPurgeable]	setState:selectedResource.attributes & resPurgeable];
		[[attributesMatrix cellWithTag:resSysHeap]	    setState:selectedResource.attributes & resSysHeap];

        rType.stringValue = GetNSStringFromOSType(selectedResource.type);
        rID.intValue = selectedResource.resID;
        rSize.integerValue = selectedResource.data.length;
        
        // swap box
        placeholderView.contentView = resourceView;
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
    if ([controller.document isKindOfClass:ResourceDocument.class]) {
        currentDocument = controller.document;
        [self setSelectedResource:currentDocument.outlineView.selectedItem];
    } else {
        currentDocument = nil;
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
    NSOutlineView *outlineView = notification.object;
    if (outlineView.window.windowController.document == currentDocument) {
        [self setSelectedResource:[notification.object selectedItem]];
    }
}

- (void)propertiesDidChange:(NSNotification *)notification
{
	[self updateInfoWindow];
}

- (IBAction)creatorChanged:(id)sender
{
    currentDocument.creator = GetOSTypeFromNSString(creator.stringValue);
}

- (IBAction)typeChanged:(id)sender
{
    currentDocument.type = GetOSTypeFromNSString(type.stringValue);
}

- (IBAction)nameChanged:(id)sender
{
    selectedResource.name = nameView.stringValue;
}

- (IBAction)rTypeChanged:(id)sender
{
    selectedResource.type = GetOSTypeFromNSString(rType.stringValue);
    rType.stringValue = GetNSStringFromOSType(selectedResource.type); // Reload in case change was rejected
}

- (IBAction)rIDChanged:(id)sender
{
    selectedResource.resID = (ResID)rID.intValue;
    rID.intValue = selectedResource.resID;
}

- (IBAction)attributesChanged:(id)sender
{
    selectedResource.attributes ^= (short)[sender selectedTag];
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
