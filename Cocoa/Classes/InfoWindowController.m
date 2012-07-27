#import "InfoWindowController.h"
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework, but <Carbon/CarbonCore.h> and <CarbonCore/CarbonCore.h> don't work, so I don't know what else to do
#import "ResourceDocument.h"
#import "Resource.h"
#import "ApplicationDelegate.h"
#import "NSOutlineView-SelectedItems.h"
//#import "MoreFilesX.h"

@implementation InfoWindowController

static OSErr
FSGetForkSizes(
			   const FSRef *ref,
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
	require_noerr(result, FSGetCatalogInfo);
	
	/* make sure FSRef was to a file */
	require_action(0 == (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask), FSRefNotFile, result = notAFileErr);
	
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
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// set window to only accept key when editing text boxes
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
	
	// retain views for swapping in and out
	[[documentView retain] removeFromSuperview];
	[[resourceView retain] removeFromSuperview];
	
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
	
	if(selectedResource)
	{
		// set UI values
		[[self window] setTitle:NSLocalizedString(@"Resource Info",nil)];
		[nameView setStringValue:[selectedResource name]];
		[iconView setImage:[(ApplicationDelegate *)[NSApp delegate] iconForResourceType:[selectedResource type]]];
		[[attributesMatrix cellAtRow:changedBox column:0]	setState:[[selectedResource attributes] shortValue] & resChanged];
		[[attributesMatrix cellAtRow:preloadBox column:0]	setState:[[selectedResource attributes] shortValue] & resPreload];
		[[attributesMatrix cellAtRow:protectedBox column:0]	setState:[[selectedResource attributes] shortValue] & resProtected];
		[[attributesMatrix cellAtRow:lockedBox column:0]	setState:[[selectedResource attributes] shortValue] & resLocked];
		[[attributesMatrix cellAtRow:purgableBox column:0]	setState:[[selectedResource attributes] shortValue] & resPurgeable];
		[[attributesMatrix cellAtRow:systemHeapBox column:0] setState:[[selectedResource attributes] shortValue] & resSysHeap];
		
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
		
		FourCharCode creator;
		[[currentDocument creator] getBytes:&creator length:sizeof(creator)];
		FourCharCode type;
		[[currentDocument type] getBytes:&type length:sizeof(type)];
		
		creator = CFSwapInt32BigToHost(creator);
		type = CFSwapInt32BigToHost(type);

		[[filePropertyForm cellAtIndex:0] setStringValue:[[[NSString alloc] initWithBytes:&creator length:sizeof(creator) encoding:NSMacOSRomanStringEncoding] autorelease]];
		[[filePropertyForm cellAtIndex:1] setStringValue:[[[NSString alloc] initWithBytes:&type length:sizeof(type) encoding:NSMacOSRomanStringEncoding] autorelease]];
//		[[filePropertyForm cellAtIndex:2] setObjectValue:[NSNumber numberWithUnsignedLongLong:dataLogicalSize]];
//		[[filePropertyForm cellAtIndex:3] setObjectValue:[NSNumber numberWithUnsignedLongLong:rsrcLogicalSize]];
		[[filePropertyForm cellAtIndex:2] setStringValue:[[NSNumber numberWithUnsignedLongLong:dataLogicalSize] description]];
		[[filePropertyForm cellAtIndex:3] setStringValue:[[NSNumber numberWithUnsignedLongLong:rsrcLogicalSize] description]];
		
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
	
	if(currentDocument)
		selectedResource = [[currentDocument outlineView] selectedItem];
	else selectedResource = [controller resource];
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
	selectedResource = (Resource *) [[notification object] selectedItem];
	[self updateInfoWindow];
}

- (void)documentInfoDidChange:(NSNotification *)notification
{
#pragma unused(notification)
	currentDocument = [[notification object] objectForKey:@"NSDocument"];
	[self updateInfoWindow];
}

- (IBAction)attributesChanged:(id)sender
{
	short attr = (short)(0x0001 << [sender selectedRow]+1);
	short number = ([[selectedResource attributes] shortValue] ^ attr);
	[selectedResource setAttributes:[NSNumber numberWithShort:number]];
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
		sharedInfoWindowController = [[InfoWindowController allocWithZone:[self zone]] initWithWindowNibName:@"InfoWindow"];
	return sharedInfoWindowController;
}

@end

@implementation NSWindowController (InfoWindowAdditions)

- (Resource *)resource
{
	return nil;
}

@end