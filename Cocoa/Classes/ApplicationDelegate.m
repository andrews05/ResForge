#import "ApplicationDelegate.h"
#import "InfoWindowController.h"
#import "PrefsWindowController.h"
#import "CreateResourceSheetController.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"

#import "ResknifePluginProtocol.h"

@implementation ApplicationDelegate

- (id)init
{
	self = [super init];
	[NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType] returnTypes:[NSArray arrayWithObject:NSStringPboardType]];
	return self;
}

- (void)awakeFromNib
{
	// Part of my EvilPlanª to find out how many people use ResKnife and how often!
	int launchCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"LaunchCount"];
	[[NSUserDefaults standardUserDefaults] setInteger:launchCount + 1 forKey:@"LaunchCount"];
	
    [self initUserDefaults];
}    

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
#pragma unused( sender )
	NSString *launchAction = [[NSUserDefaults standardUserDefaults] stringForKey:@"LaunchAction"];
    if( [launchAction isEqualToString:@"OpenUntitledFile"] )
		return YES;
	else if( [launchAction isEqualToString:@"DisplayOpenPanel"] )
	{
		[[NSDocumentController sharedDocumentController] openDocument:sender];
		return NO;
	}
	else return NO;	// should be @"None", but we shall return NO for any other value
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
#pragma unused( sender )
	return !flag;
}

- (IBAction)showAbout:(id)sender
{
	[NSApp orderFrontStandardAboutPanel:sender];
	// get about box code from http://cocoadevcentral.com/tutorials/showpage.php?show=00000041.php
}

- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://nickshanks.com/resknife/"]];
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
	
	NSUserDefaults *defaults;
	NSDictionary *defaultsPlist;
	NSEnumerator *overDefaults;
	id eachDefault;
	
	// this isn't required, but saves us a few method calls
	defaults = [NSUserDefaults standardUserDefaults];
	
	// load the defaults.plist from the app wrapper.  This makes it
	//	easy to add new defaults just using a text editor instead of
	//	hard-coding them into the application
	defaultsPlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]];
	
	// enumerate over all the keys in the dictionary
	overDefaults = [[defaultsPlist allKeys] objectEnumerator];
	while( eachDefault = [overDefaults nextObject] )
	{
		// for each key in the dictionary
		//	check if there is a value already registered for it
		//	and if there isn't, then register the value that was in the file
		if( ![defaults stringForKey:eachDefault] )
		{
			[defaults setObject:[defaultsPlist objectForKey:eachDefault] forKey:eachDefault];
		}
	}
	
	// force the defaults to save to the disk
	[defaults synchronize];
}

@end

@implementation NSSavePanel (PackageBrowser)

/* Don't tell anyone I did this... */

- (void)setTreatsFilePackagesAsDirectories:(BOOL)flag
{
#pragma unused( flag )
	_spFlags.treatsFilePackagesAsDirectories = YES;
}

@end