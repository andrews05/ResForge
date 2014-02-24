#import "PrefsWindowController.h"

NSString * const kPreserveBackups = @"PreserveBackups";
NSString * const kAutosave = @"Autosave";
NSString * const kAutosaveInterval = @"AutosaveInterval";
NSString * const kDeleteResourceWarning =  @"DeleteResourceWarning";
NSString * const kLaunchAction = @"LaunchAction";
NSString * const kOpenUntitledFile = @"OpenUntitledFile";
NSString * const kDisplayOpenPanel = @"DisplayOpenPanel";
NSString * const kNoLaunchOption = @"None";

@implementation PrefsWindowController

- (id)init
{
	return self = [self initWithWindowNibName:@"PrefsWindow"];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)awakeFromNib
{
	// represent current prefs in window state
	[self updatePrefs:nil];
	[[self window] center];
	
	// listen out for pref changes from elsewhere
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePrefs:) name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void)updatePrefs:(NSNotification *)notification
{
	// load preferences…
	NSUserDefaults *defaults	= [NSUserDefaults standardUserDefaults];
	BOOL preserveBackups		= [defaults boolForKey:kPreserveBackups];
	BOOL autosave				= [defaults boolForKey:kAutosave];
	NSInteger autosaveInterval		= [defaults integerForKey:kAutosaveInterval];
	BOOL deleteResourceWarning	= [defaults boolForKey:kDeleteResourceWarning];
	BOOL createNewDocument		= [[defaults stringForKey:kLaunchAction] isEqualToString:kOpenUntitledFile];
	BOOL displayOpenPanel		= [[defaults stringForKey:kLaunchAction] isEqualToString:kDisplayOpenPanel];
	int launchAction			= createNewDocument? 1:(displayOpenPanel? 2:0);
	
	// …and set widgets accordingly
	[[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] setState:preserveBackups];
	[[dataProtectionMatrix cellAtRow:autosaveBox column:0] setState:autosave];
	[autosaveIntervalField setStringValue:[NSString stringWithFormat:@"%ld", (long)autosaveInterval]];
	[[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] setState:deleteResourceWarning];
	[launchActionMatrix selectCellAtRow:launchAction column:0];
}

- (IBAction)acceptPrefs:(id)sender
{
	// bug: hey! where's NSValue's boolValue method? I have to use "intValue? YES:NO" :(
	NSUserDefaults *defaults	= [NSUserDefaults standardUserDefaults];
	BOOL preserveBackups		= [[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] intValue]? YES:NO;
	BOOL autosave				= [[dataProtectionMatrix cellAtRow:autosaveBox column:0] intValue]? YES:NO;
	int autosaveInterval		= [autosaveIntervalField intValue];
	BOOL deleteResourceWarning	= [[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] intValue]? YES:NO;
	BOOL createNewDocument		= ([launchActionMatrix selectedRow] == createNewDocumentBox)? YES:NO;
	BOOL displayOpenPanel		= ([launchActionMatrix selectedRow] == displayOpenPanelBox)? YES:NO;
	
	// hide the window
	[[self window] orderOut:nil];
	
	// now save the data to the defaults file
	[defaults setBool:preserveBackups forKey:kPreserveBackups];	// bug: this puts 1 or 0 into the defaults file rather than YES or NO
	[defaults setBool:autosave forKey:kAutosave];
	[defaults setInteger:autosaveInterval forKey:kAutosaveInterval];
	[defaults setBool:deleteResourceWarning forKey:kDeleteResourceWarning];
	if(createNewDocument)		[defaults setObject:kOpenUntitledFile forKey:kLaunchAction];
	else if(displayOpenPanel)	[defaults setObject:kDisplayOpenPanel forKey:kLaunchAction];
	else						[defaults setObject:kNoLaunchOption forKey:kLaunchAction];
	[defaults synchronize];
}

- (IBAction)cancelPrefs:(id)sender
{
	// hide the window
	[[self window] orderOut:nil];
	
	// reset widgets to saved values
	[self updatePrefs:nil];
}

- (IBAction)resetToDefault:(id)sender
{
	// reset prefs window widgets to values stored in defaults.plist file
	NSDictionary *defaultsPlist	= [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]];
	BOOL preserveBackups		= [[defaultsPlist objectForKey:kPreserveBackups] intValue]? YES:NO;	// bug: this always evaluates to NO, even if the object in the dictionary is YES
	BOOL autosave				= [[defaultsPlist objectForKey:kAutosave] intValue]? YES:NO;
	int autosaveInterval		= [[defaultsPlist objectForKey:kAutosaveInterval] intValue];
	BOOL deleteResourceWarning	= [[defaultsPlist objectForKey:kDeleteResourceWarning] intValue]? YES:NO;
	BOOL createNewDocument		= [[defaultsPlist objectForKey:kLaunchAction] isEqualToString:kOpenUntitledFile];
	BOOL displayOpenPanel		= [[defaultsPlist objectForKey:kLaunchAction] isEqualToString:kDisplayOpenPanel];
	int launchAction			= createNewDocument? 1:(displayOpenPanel? 2:0);
	
	// note that this function does not modify the user defaults - the user still has to accept or cancel the panel
	[[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] setState:preserveBackups];
	[[dataProtectionMatrix cellAtRow:autosaveBox column:0] setState:autosave];
	[autosaveIntervalField setStringValue:[NSString stringWithFormat:@"%d", autosaveInterval]];
	[[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] setState:deleteResourceWarning];
	[launchActionMatrix selectCellAtRow:launchAction column:0];
}

+ (id)sharedPrefsWindowController
{
	static PrefsWindowController *sharedPrefsWindowController = nil;
	if( !sharedPrefsWindowController )
		sharedPrefsWindowController = [[PrefsWindowController allocWithZone:[self zone]] init];
	return sharedPrefsWindowController;
}

@end
