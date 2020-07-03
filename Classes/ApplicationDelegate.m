#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"
#import "RKDocumentController.h"
#import "InfoWindowController.h"
#import "PasteboardWindowController.h"
#import "PrefsController.h"
#import "CreateResourceSheetController.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "RKEditorRegistry.h"

#import "ResKnifePluginProtocol.h"
#import "RKSupportResourceRegistry.h"


@implementation ApplicationDelegate

+ (void)initialize
{
	// set default preferences
	NSDictionary * prefDict = @{kPreserveBackups: @NO,
								kDeleteResourceWarning: @YES,
                                kLaunchAction: kDisplayOpenPanel};
	[[NSUserDefaults standardUserDefaults] registerDefaults:prefDict];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:prefDict];
}

- (instancetype)init
{
	if (self = [super init]) {
		[NSApp registerServicesMenuSendTypes:@[NSStringPboardType] returnTypes:@[NSStringPboardType]];
	}
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// instanciate my own subclass of NSDocumentController so I can override the open dialog
	// autorelease to fix an analyzer warning; the application already holds onto the document controller
	[RKSupportResourceRegistry scanForSupportResources];
}

/*!
@method		awakeFromNib
@updated	2003-10-24 NGS: moved icon caching into method called by timer (to speed up app launch time)
*/

- (void)awakeFromNib
{
	// Part of my EvilPlan� to find out how many people use ResKnife and how often!
	NSInteger launchCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"LaunchCount"];
	[[NSUserDefaults standardUserDefaults] setInteger:launchCount + 1 forKey:@"LaunchCount"];
	
	// initalise an empty icon cache and create timer used to pre-cache a number of common icons
	_icons = [[NSMutableDictionary alloc] init];
    [self precacheIcons: nil];
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
	[self iconForResourceType:'    '];
	[self iconForResourceType:0x3f3f3f3f];
	[self iconForResourceType:'CODE'];
	[self iconForResourceType:'icns'];
	[self iconForResourceType:'PICT'];
	[self iconForResourceType:'plst'];
	[self iconForResourceType:'snd '];
	[self iconForResourceType:'TEXT'];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
#pragma unused(sender)
	NSString *launchAction = [[NSUserDefaults standardUserDefaults] stringForKey:kLaunchAction];
    if ([launchAction isEqualToString:kOpenUntitledFile]) {
		return YES;
    } else if([launchAction isEqualToString:kDisplayOpenPanel]) {
		[[NSDocumentController sharedDocumentController] openDocument:sender];
		return NO;
	}
	else return NO;	// should be @"None", but we shall return NO for any other value
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
    if (!self.prefsController)
        self.prefsController = [[NSWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    [self.prefsController showWindow:sender];
    [self.prefsController.window makeKeyAndOrderFront:sender];
}

/*!
@method			iconForResourceType:
@author			Nicholas Shanks
@created		2003-10-24
@abstract		Manages the cache of icons used for representing resource types.
@description	This method loads icons for each resource type from a variety of places and caches them for faster access. Your plug-in may be asked to return an icon for any resource type it declares it can edit. To implement this, your plug should respond to the iconForResourceType: selector with the same method signature as this method. The icons can be in any format recognised by NSImage. Alternativly, just leave your icons in "Your.plugin/Contents/Resources/Resource Type Icons/" (or any equivalent localised directory) with a name like "TYPE.tiff" and ResKnife will retrieve them automatically.
@pending		I don't like the name I chose here for the resource type icons directory. Can anyone think of something better?
*/

- (NSImage *)iconForResourceType:(OSType)resourceType
{
	NSImage *icon;
	
	if(resourceType)
	{
		// check if we have image in cache already
		icon = [self _icons][GetNSStringFromOSType(resourceType)];		// valueForKey: raises when the resourceType begins with '@' (e.g. the @GN4 owner resource from Gene!)
		
		if(!icon)
		{
			NSString *iconPath = nil;
			
			// try to load icon from the default editor for that type
			Class editor = [[RKEditorRegistry defaultRegistry] editorForType:GetNSStringFromOSType(resourceType)];
			if(editor)
			{
				// ask politly for icon
				if([editor respondsToSelector:@selector(iconForResourceType:)])
					icon = [(id)editor iconForResourceType:resourceType];
				
				// try getting it myself
				if(!icon)
				{
					iconPath = [[NSBundle bundleForClass:editor] pathForResource:GetNSStringFromOSType(resourceType) ofType:nil inDirectory:@"Resource Type Icons"];
					if(iconPath)
						icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
				}
			}
			
			// try to load icon from the ResKnife app bundle itself
			if(!icon)
			{
				iconPath = [[NSBundle mainBundle] pathForResource:GetNSStringFromOSType(resourceType) ofType:nil inDirectory:@"Resource Type Icons"];
				if(iconPath)
					icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
			}
			
			// try to retrieve from file system using our resource type to file name extension/bundle identifier code
			if(!icon)
			{
				NSString *fileType = [[NSBundle mainBundle] localizedStringForKey:GetNSStringFromOSType(resourceType) value:@"" table:@"Resource Type Mappings"];
				NSRange range = [fileType rangeOfString:@"."];
				if(range.location == NSNotFound)
					icon = [[NSWorkspace sharedWorkspace] iconForFileType:[fileType lowercaseString]];
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
				icon = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithFormat:@"'%@'", GetNSStringFromOSType(resourceType)]];
			
			// save the newly retrieved icon in the cache
			if(icon)
				[self _icons][GetNSStringFromOSType(resourceType)] = icon;
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
