#import "InfoWindowController.h"
@import CoreServices.CarbonCore;
#import "ResourceDocument.h"
#import "Resource.h"
#import "ApplicationDelegate.h"
#import "NSOutlineView-SelectedItems.h"
//#import "MoreFilesX.h"

@implementation InfoWindowController

static OSErr
FSGetForkSizes(const FSRef *ref,
			   UInt64 *dataLogicalSize,	/* can be NULL */
			   UInt64 *rsrcLogicalSize)	/* can be NULL */
{
	OSErr				result;
	FSCatalogInfoBitmap whichInfo;
	FSCatalogInfo		catalogInfo;
	
	whichInfo = kFSCatInfoNodeFlags;
	if ( NULL != dataLogicalSize )
	{
		/* get data fork size */
		whichInfo |= kFSCatInfoDataSizes;
	}
	if ( NULL != rsrcLogicalSize )
	{
		/* get resource fork size */
		whichInfo |= kFSCatInfoRsrcSizes;
	}
	
	/* get nodeFlags and catalog info */
	result = FSGetCatalogInfo(ref, whichInfo, &catalogInfo, NULL, NULL,NULL);
	__Require_noErr(result, FSGetCatalogInfo);
	
	/* make sure FSRef was to a file */
	__Require_Action(0 == (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask), FSRefNotFile, result = notAFileErr);
	
	if ( NULL != dataLogicalSize )
	{
		/* return data fork size */
		*dataLogicalSize = catalogInfo.dataLogicalSize;
	}
	if ( NULL != rsrcLogicalSize )
	{
		/* return resource fork size */
		*rsrcLogicalSize = catalogInfo.rsrcLogicalSize;
	}
	
FSRefNotFile:
FSGetCatalogInfo:
	
	return ( result );
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// set window to only accept key when editing text boxes
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
	
	// retain views for swapping in and out
	[documentView removeFromSuperview];
	[resourceView removeFromSuperview];
	
	[self setMainWindow:[NSApp mainWindow]];
	[self updateInfoWindow];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedResourceChanged:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesDidChange:) name:ResourceAttributesDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentInfoDidChange:) name:DocumentInfoDidChangeNotification object:nil];
}

/*!
@method		updateInfoWindow
@updated	2003-11-06 NGS:	Fixed creator/type handling.
@updated	2003-10-26 NGS:	Now asks app delegate for icon instead of NSWorkspace.
@updated	2003-10-26 NGS:	Improved document name & icon display.
*/

- (void)updateInfoWindow
{
	[nameView setEditable:(selectedResource != nil)];
	[nameView setDrawsBackground:(selectedResource != nil)];
	
	if(selectedResource && [selectedResource isKindOfClass:[Resource class]])
	{
		// set UI values
		[[self window] setTitle:NSLocalizedString(@"Resource Info",nil)];
		[nameView setStringValue:[selectedResource name]];
		[iconView setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:[selectedResource type]]];
		[[attributesMatrix cellAtRow:changedBox column:0]		setState:[selectedResource attributes] & resChanged];
		[[attributesMatrix cellAtRow:preloadBox column:0]		setState:[selectedResource attributes] & resPreload];
		[[attributesMatrix cellAtRow:protectedBox column:0]		setState:[selectedResource attributes] & resProtected];
		[[attributesMatrix cellAtRow:lockedBox column:0]		setState:[selectedResource attributes] & resLocked];
		[[attributesMatrix cellAtRow:purgableBox column:0]		setState:[selectedResource attributes] & resPurgeable];
		[[attributesMatrix cellAtRow:systemHeapBox column:0]	setState:[selectedResource attributes] & resSysHeap];
		
		// swap box
		[placeholderView setContentView:resourceView];
	}
	else if(currentDocument != nil)
	{
		// get sizes of forks as they are on disk
		UInt64 dataLogicalSize = 0, rsrcLogicalSize = 0;
		FSRef *fileRef = (FSRef *) NewPtrClear(sizeof(FSRef));
		if(fileRef && [currentDocument fileURL])
		{
			OSStatus error = FSPathMakeRef((unsigned char *)[[[currentDocument fileURL] path] fileSystemRepresentation], fileRef, nil);
			if(!error) FSGetForkSizes(fileRef, &dataLogicalSize, &rsrcLogicalSize);
		}
		if(fileRef) DisposePtr((Ptr) fileRef);
		
		// set info window elements to correct values
		[[self window] setTitle:NSLocalizedString(@"Document Info",nil)];
		if([currentDocument fileURL])	// document has been saved
		{
			[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFile:[[currentDocument fileURL] path]]];
			[nameView setStringValue:[[currentDocument fileURL] lastPathComponent]];
		}
		else								// new, untitled document
		{
			[iconView setImage:[NSImage imageNamed:@"Resource file"]];
			[nameView setStringValue:[currentDocument displayName]];
		}
		
		FourCharCode creator = currentDocument.creator;
		FourCharCode type = currentDocument.type;
		
		[[filePropertyForm cellAtIndex:0] setStringValue:[[NSString alloc] initWithBytes:&creator length:sizeof(creator) encoding:NSMacOSRomanStringEncoding]];
		[[filePropertyForm cellAtIndex:1] setStringValue:[[NSString alloc] initWithBytes:&type length:sizeof(type) encoding:NSMacOSRomanStringEncoding]];
		[[filePropertyForm cellAtIndex:2] setIntegerValue:dataLogicalSize];
		[[filePropertyForm cellAtIndex:3] setIntegerValue:rsrcLogicalSize];
		//[[filePropertyForm cellAtIndex:2] setStringValue:[@(dataLogicalSize) description]];
		//[[filePropertyForm cellAtIndex:3] setStringValue:[@(rsrcLogicalSize) description]];
		
		// swap box
		[placeholderView setContentView:documentView];
	}
	else
	{
		[iconView setImage:nil];
		[nameView setStringValue:@""];
		[placeholderView setContentView:nil];
	}
}

- (void)setMainWindow:(NSWindow *)mainWindow
{
	NSWindowController *controller = [mainWindow windowController];
	
	if([[controller document] isKindOfClass:[ResourceDocument class]])
		currentDocument = [controller document];
	else currentDocument = nil;
	
    if (currentDocument) {
        [self setSelectedResource:[[currentDocument outlineView] selectedItem]];
    } else {
        [self setSelectedResource:[controller resource]];
    }
}

- (void)setSelectedResource:(Resource *)resource
{
    if ([resource isKindOfClass:[Resource class]] && [resource representedFork] == nil) {
        selectedResource = resource;
    } else {
        selectedResource = nil;
    }
    [self updateInfoWindow];
}

- (void)mainWindowChanged:(NSNotification *)notification
{
	[self setMainWindow:[notification object]];
}

- (void)selectedResourceChanged:(NSNotification *)notification
{
	if(![[nameView stringValue] isEqualToString:[selectedResource name]])
		[self nameDidChange:nameView];
	[self setSelectedResource:[[notification object] selectedItem]];
}

- (void)documentInfoDidChange:(NSNotification *)notification
{
#pragma unused(notification)
	currentDocument = [notification object][@"NSDocument"];
	[self updateInfoWindow];
}

- (IBAction)attributesChanged:(id)sender
{
	short attr = (short)(0x0001 << ([sender selectedRow]+1));
	short number = ([selectedResource attributes] ^ attr);
	[selectedResource setAttributes:number];
}

- (IBAction)nameDidChange:(id)sender
{
	[selectedResource setName:[nameView stringValue]];
}

- (void)resourceAttributesDidChange:(NSNotification *)notification;
{
	[self updateInfoWindow];
}

+ (id)sharedInfoWindowController
{
	static InfoWindowController *sharedInfoWindowController = nil;
	if(!sharedInfoWindowController)
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
