#import "InfoWindowController.h"
#import <Carbon/Carbon.h>	// Actually I only need CarbonCore.framework, but <Carbon/CarbonCore.h> and <CarbonCore/CarbonCore.h> don't work, so I don't know what else to do
#import "ResourceDocument.h"
#import "Resource.h"
#import "NSOutlineView-SelectedItems.h"
#import "MoreFilesX.h"

@implementation InfoWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"InfoWindow"];
	if( self ) [self setWindowFrameAutosaveName:@"InfoWindow"];
	return self;
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
	[documentView retain];
	[documentView removeFromSuperview];
	[resourceView retain];
	[resourceView removeFromSuperview];
	
	[self setMainWindow:[NSApp mainWindow]];
	[self updateInfoWindow];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedResourceChanged:) name:NSOutlineViewSelectionDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesDidChange:) name:ResourceAttributesDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentInfoDidChange:) name:DocumentInfoDidChangeNotification object:nil];
}

- (void)updateInfoWindow
{
	if( selectedResource )
	{
		[[self window] setTitle:@"Resource Info"];
		[placeholderView setContentView:resourceView];
		[nameView setStringValue:[selectedResource name]];
		[iconView setImage:[[NSWorkspace sharedWorkspace] iconForFileType:[selectedResource type]]];
		[[attributesMatrix cellAtRow:changedBox column:0]	setState:[[selectedResource attributes] shortValue] & resChanged];
		[[attributesMatrix cellAtRow:preloadBox column:0]	setState:[[selectedResource attributes] shortValue] & resPreload];
		[[attributesMatrix cellAtRow:protectedBox column:0]	setState:[[selectedResource attributes] shortValue] & resProtected];
		[[attributesMatrix cellAtRow:lockedBox column:0]	setState:[[selectedResource attributes] shortValue] & resLocked];
		[[attributesMatrix cellAtRow:purgableBox column:0]	setState:[[selectedResource attributes] shortValue] & resPurgeable];
		[[attributesMatrix cellAtRow:systemHeapBox column:0] setState:[[selectedResource attributes] shortValue] & resSysHeap];
	}
	else
	{
		// get sizes of forks as they are on disk
		UInt64 dataLogicalSize = 0, rsrcLogicalSize = 0;
		FSRef *fileRef = (FSRef *) NewPtrClear( sizeof(FSRef) );
		if( fileRef && [currentDocument fileName] )
		{
			OSStatus error = FSPathMakeRef( [[currentDocument fileName] cString], fileRef, nil );
			if( !error ) FSGetForkSizes( fileRef, &dataLogicalSize, &rsrcLogicalSize );
		}
		if( fileRef ) DisposePtr( (Ptr) fileRef );
		
		// set info window elements to correct values
		[[self window] setTitle:@"Document Info"];
		[iconView setImage:[NSImage imageNamed:@"Resource file"]];
		[nameView setStringValue:[currentDocument fileName]? [[currentDocument fileName] lastPathComponent]:[currentDocument displayName]];
		[[filePropertyForm cellAtIndex:0] setStringValue:[currentDocument creator]];
		[[filePropertyForm cellAtIndex:1] setStringValue:[currentDocument type]];
//		[[filePropertyForm cellAtIndex:2] setObjectValue:[NSNumber numberWithUnsignedLongLong:dataLogicalSize]];
//		[[filePropertyForm cellAtIndex:3] setObjectValue:[NSNumber numberWithUnsignedLongLong:rsrcLogicalSize]];
		[[filePropertyForm cellAtIndex:2] setStringValue:[NSNumber numberWithUnsignedLongLong:dataLogicalSize]];
		[[filePropertyForm cellAtIndex:3] setStringValue:[NSNumber numberWithUnsignedLongLong:rsrcLogicalSize]];
		[placeholderView setContentView:documentView];
	}
}

- (void)setMainWindow:(NSWindow *)mainWindow
{
	NSWindowController *controller = [mainWindow windowController];
	
	if( [[controller document] isKindOfClass:[ResourceDocument class]] )
		currentDocument = [controller document];
	else currentDocument = nil;
	
	selectedResource = [[currentDocument outlineView] selectedItem];
	[self updateInfoWindow];
}

- (void)mainWindowChanged:(NSNotification *)notification
{
	[self setMainWindow:[notification object]];
}

- (void)selectedResourceChanged:(NSNotification *)notification
{
	selectedResource = [[notification object] selectedItem];
	[self updateInfoWindow];
}

- (void)documentInfoDidChange:(NSNotification *)notification
{
#pragma unused( notification )
	[self updateInfoWindow];
}

- (IBAction)attributesChanged:(id)sender
{
	short attr = 0x0001 << [sender selectedRow]+1;
	short number = ([[selectedResource attributes] shortValue] ^ attr);
	[selectedResource setAttributes:[NSNumber numberWithShort:number]];
}

- (void)resourceAttributesDidChange:(NSNotification *)notification;
{
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
