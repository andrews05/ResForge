#import "ApplicationDelegate.h"
#import "InfoWindowController.h"
#import "PrefsWindowController.h"
#import "ResourceDataSource.h"
#import "CreateResourceSheetController.h"

@implementation ApplicationDelegate

- (id)init
{
	self = [super init];
	[NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:@"NSString"] returnTypes:[NSArray arrayWithObject:@"NSString"]];
	return self;
}

- (void)awakeFromNib
{
	// Part of my EvilPlanª to find out how many people use ResKnife and how often!
	int launchCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"LaunchCount"];
	[[NSUserDefaults standardUserDefaults] setInteger:launchCount + 1 forKey:@"LaunchCount"];
	
    [self initUserDefaults];
}    

- (IBAction)showInfo:(id)sender
{
	[[InfoWindowController sharedInfoWindowController] showWindow:sender];
}

- (IBAction)showPrefs:(id)sender
{
	[[PrefsWindowController sharedPrefsWindowController] showWindow:sender];
}

- (IBAction)showCreateResourceSheet:(id)sender
{
	// bug: requires ALL main window's delegates to have 'dataSource' declared,
	//	would be better to use a resourceDocument variable which could point to self for document windows.
	return [[[[[NSApp mainWindow] delegate] dataSource] createResourceSheetController] showCreateResourceSheet:sender];
}

- (IBAction)openResource:(id)sender
{
//	[NSBundle loadNibNamed:@"HexWindow" owner:self]; 
//- (NSString *)pathForAuxiliaryExecutable:(NSString *)executableName;
//	[[NSBundle bundleWithIdentifier:@"com.nickshanks.resknife.hexadecimal"] load];
	[[NSBundle bundleWithPath:[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"HexEditor.plugin"]] load];
}

- (IBAction)playSound:(id)sender
{
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
