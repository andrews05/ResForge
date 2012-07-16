#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"
#import "RKDocumentController.h"
#import "InfoWindowController.h"
#import "PasteboardWindowController.h"
#import "PrefsWindowController.h"
#import "CreateResourceSheetController.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "RKEditorRegistry.h"

#import "ResKnifePluginProtocol.h"
#import "RKSupportResourceRegistry.h"


@implementation ApplicationDelegate

- (id)init
{
	self = [super init];
	[NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType] returnTypes:[NSArray arrayWithObject:NSStringPboardType]];
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// instanciate my own subclass of NSDocumentController so I can override the open dialog
	// autorelease to fix an analyzer warning; the application already holds onto the document controller
	[[[RKDocumentController alloc] init] autorelease];
	[RKSupportResourceRegistry scanForSupportResources];
}

/*!
@method		awakeFromNib
@updated	2003-10-24 NGS: moved icon caching into method called by timer (to speed up app launch time)
*/

- (void)awakeFromNib
{
	// Part of my EvilPlanª to find out how many people use ResKnife and how often!
	int launchCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"LaunchCount"];
	[[NSUserDefaults standardUserDefaults] setInteger:launchCount + 1 forKey:@"LaunchCount"];
	
	// initalise an empty icon cache and create timer used to pre-cache a number of common icons
	_icons = [[NSMutableDictionary alloc] init];
	[NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(precacheIcons:) userInfo:nil repeats:NO];
	
	// set default preferences
    [self initUserDefaults];
}

- (void)dealloc
{
	[_icons release];
	[super dealloc];
}

/*!
@method			precacheIcons:
@author			Nicholas Shanks
@created		2003-10-24
@abstract		Pre-caches the icons for a number of common resource types.
@description	Icon pre-caching now uses the more sophisticated iconForResourceType: instead of obtaining the images directly from the file system (otherwise pre-cached icons would not be overridable by plug-ins). In addition it has been moved from the awakeFromNib: method into one called by a timer. This method should not be called until after the editor registry has been built.
*/

- (void)precacheIcons:(NSTimer *)timer
{
	// pre-cache a number of common icons (ignores return value, relies on iconForResourceType: to do the actual caching)
	[self iconForResourceType:@"    "];
	[self iconForResourceType:@"????"];
	[self iconForResourceType:@"CODE"];
	[self iconForResourceType:@"icns"];
	[self iconForResourceType:@"PICT"];
	[self iconForResourceType:@"plst"];
	[self iconForResourceType:@"snd "];
	[self iconForResourceType:@"TEXT"];
}

- (NSArray *)forksForFile:(FSRef *)fileRef
{
	if(!fileRef) return nil;
	
	FSCatalogInfo		catalogInfo;
	FSCatalogInfoBitmap whichInfo = kFSCatInfoNodeFlags;
	CatPositionRec		forkIterator = { 0 };
	NSMutableArray *forks = [NSMutableArray array];
	
	// check we have a file, not a folder
	OSErr error = FSGetCatalogInfo(fileRef, whichInfo, &catalogInfo, NULL, NULL, NULL);
	if(!error && !(catalogInfo.nodeFlags & kFSNodeIsDirectoryMask))
	{
		// iterate over file and populate forks array
		while(error == noErr)
		{
			HFSUniStr255 forkName;
			SInt64 forkSize;
			UInt64 forkPhysicalSize;	// used if opening selected fork fails to find empty forks
			
			error = FSIterateForks(fileRef, &forkIterator, &forkName, &forkSize, &forkPhysicalSize);
			if(!error)
			{
				NSString *fName = [NSString stringWithCharacters:forkName.unicode length:forkName.length];
				NSNumber *fSize = [NSNumber numberWithLongLong:forkSize];
				NSNumber *fAlloc = [NSNumber numberWithUnsignedLongLong:forkPhysicalSize];
				[forks addObject:[NSDictionary dictionaryWithObjectsAndKeys:fName, @"forkname", fSize, @"forksize", fAlloc, @"forkallocation", nil]];
			}
			else if(error != errFSNoMoreItems)
			{
				NSLog(@"FSIterateForks() error: %d", error);
			}
		}
	}
	else if(error)
	{
		NSLog(@"FSGetCatalogInfo() error: %d", error);
	}
	return forks;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
#pragma unused(sender)
	NSString *launchAction = [[NSUserDefaults standardUserDefaults] stringForKey:@"LaunchAction"];
	if([launchAction isEqualToString:@"OpenUntitledFile"])
		return YES;
	else if([launchAction isEqualToString:@"DisplayOpenPanel"])
	{
		[[NSDocumentController sharedDocumentController] openDocument:sender];
		return NO;
	}
	else return NO;	// should be @"None", but we shall return NO for any other value
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)file
{
#pragma unused(application)
	// bug: check if application was an external editor (e.g. Iconographer) and update existing open file instead
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:file display:YES];
	return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
#pragma unused(sender)
	return !flag;
}

- (IBAction)showAbout:(id)sender
{
	// could do with a better about box
/*	NSWindowController *wc = [[NSWindowController alloc] initWithWindowNibName:@"AboutPanel"];
	if([(NSTextView *)[[wc window] initialFirstResponder] readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]])
	{
		[[wc window] center];
		[[wc window] orderFront:nil];
	}
	else*/ [NSApp orderFrontStandardAboutPanel:sender];
}

- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://web.nickshanks.com/resknife/"]];
}

- (IBAction)visitSourceforge:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://resknife.sourceforge.net/"]];
}

- (IBAction)emailDeveloper:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:resknife@nickshanks.com?Subject=Comments,%20Suggestions%20and%20Bug%20Reports"]];
}

- (IBAction)showInfo:(id)sender
{
	[[InfoWindowController sharedInfoWindowController] showWindow:sender];
}

- (IBAction)showPasteboard:(id)sender
{
	[[PasteboardWindowController sharedPasteboardWindowController] showWindow:sender];
}

- (IBAction)showPrefs:(id)sender
{
	[[PrefsWindowController sharedPrefsWindowController] showWindow:sender];
}

- (void)initUserDefaults
{
	// This should probably be added to NSUserDefaults as a category,
	//	since its universally useful.  It loads a defaults.plist file
	//	from the app wrapper, and then sets the defaults if they don't
	//	already exist.
	
	// this isn't required, but saves us a few method calls
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// load the defaults.plist from the app wrapper.  This makes it
	//	easy to add new defaults just using a text editor instead of
	//	hard-coding them into the application
	NSDictionary *defaultsPlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]];
	[defaults registerDefaults:defaultsPlist];
	
	// force the defaults to save to the disk
	[defaults synchronize];
}

- (OpenPanelDelegate *)openPanelDelegate
{
	return openPanelDelegate;
}

/*!
@method			iconForResourceType:
@author			Nicholas Shanks
@created		2003-10-24
@abstract		Manages the cache of icons used for representing resource types.
@description	This method loads icons for each resource type from a variety of places and caches them for faster access. Your plug-in may be asked to return an icon for any resource type it declares it can edit. To implement this, your plug should respond to the iconForResourceType: selector with the same method signature as this method. The icons can be in any format recognised by NSImage. Alternativly, just leave your icons in "Your.plugin/Contents/Resources/Resource Type Icons/" (or any equivalent localised directory) with a name like "TYPE.tiff" and ResKnife will retrieve them automatically.
@pending		I don't like the name I chose here for the resource type icons directory. Can anyone think of something better?
*/

- (NSImage *)iconForResourceType:(NSString *)resourceType
{
	NSImage *icon = nil;
	if([resourceType isEqualToString:@""])
		resourceType = nil;
	
	if(resourceType)
	{
		// check if we have image in cache already
		icon = [[self _icons] objectForKey:resourceType];		// valueForKey: raises when the resourceType begins with '@' (e.g. the @GN4 owner resource from Gene!)
		
		if(!icon)
		{
			NSString *iconPath = nil;
			
			// try to load icon from the default editor for that type
			Class editor = [[RKEditorRegistry defaultRegistry] editorForType:resourceType];
			if(editor)
			{
				// ask politly for icon
				if([editor respondsToSelector:@selector(iconForResourceType:)])
					icon = [(id)editor iconForResourceType:resourceType];
				
				// try getting it myself
				if(!icon)
				{
					iconPath = [[NSBundle bundleForClass:editor] pathForResource:resourceType ofType:nil inDirectory:@"Resource Type Icons"];
					if(iconPath)
						icon = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
				}
			}
			
			// try to load icon from the ResKnife app bundle itself
			if(!icon)
			{
				iconPath = [[NSBundle mainBundle] pathForResource:resourceType ofType:nil inDirectory:@"Resource Type Icons"];
				if(iconPath)
					icon = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
			}
			
			// try to retrieve from file system using our resource type to file name extension/bundle identifier code
			if(!icon)
			{
				NSString *fileType = [[NSBundle mainBundle] localizedStringForKey:resourceType value:@"" table:@"Resource Type Mappings"];
				NSRange range = [fileType rangeOfString:@"."];
				if(range.location == NSNotFound)
					icon = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
				else	// a '.' character in a file type means ResKnife should look for a bundle icon with fileType as the bundle's identifier
				{
					NSString *bundlePath = [[NSBundle bundleWithIdentifier:fileType] bundlePath];
					if(bundlePath)
						icon = [[NSWorkspace sharedWorkspace] iconForFile:bundlePath];
				}
			}
			
			// TODO: convert to a UTI and try that 
			
			// try to retrieve from file system as an OSType code
			if(!icon)
				icon = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithFormat:@"'%@'", resourceType]];
			
			// save the newly retrieved icon in the cache
			if(icon)
				[[self _icons] setObject:icon forKey:resourceType];
		}
	}
	else
	{
		// we have no resource type, try to get a generic icon - this is what icon represented forks get
//		if(!icon)	icon = [NSImage imageNamed:@"NSMysteryDocument"];
//		if(!icon)	icon = [[NSWorkspace sharedWorkspace] iconForFileType:@"'    '"];
		if(!icon)	icon = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithFormat:@"'%@'", @"????"]];
	}
	
	// return the cached icon, or nil if none was found
	return icon;
}

- (NSMutableDictionary *)_icons
{
	return _icons;
}

- (NSDictionary *)icons
{
	return [NSDictionary dictionaryWithDictionary:[self _icons]];
}

@end