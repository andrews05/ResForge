#import "PrefsWindowController.h"

@implementation PrefsWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"PrefsWindow"];
	if( self ) [self setWindowFrameAutosaveName:@"ResKnife Preferences"];
	return self;
}

- (void)awakeFromNib
{
	// load preferences…
	NSUserDefaults*	defaults	= [NSUserDefaults standardUserDefaults];
	BOOL preserveBackups		= [defaults boolForKey:@"PreserveBackups"];
	BOOL autosave				= [defaults boolForKey:@"Autosave"];
	int autosaveInterval		= [defaults integerForKey:@"AutosaveInterval"];
	BOOL deleteResourceWarning	= [defaults boolForKey:@"DeleteResourceWarning"];
	
	// …and set widgets accordingly
	[[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] setState:preserveBackups];
	[[dataProtectionMatrix cellAtRow:autosaveBox column:0] setState:autosave];
	[autosaveIntervalField setStringValue:[NSString stringWithFormat:@"%d", autosaveInterval]];
	[[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] setState:deleteResourceWarning];
}    

- (IBAction)acceptPrefs:(id)sender
{
	// bug: hey! where's NSValue's boolValue method? I have to use "intValue? YES:NO" :(
	NSUserDefaults*	defaults	= [NSUserDefaults standardUserDefaults];
	BOOL preserveBackups		= [[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] intValue]? YES:NO;
	BOOL autosave				= [[dataProtectionMatrix cellAtRow:autosaveBox column:0] intValue]? YES:NO;
	int autosaveInterval		= [autosaveIntervalField intValue];
	BOOL deleteResourceWarning	= [[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] intValue]? YES:NO;
	
	// hide the window
	[[self window] orderOut:nil];
	
	// now save the data to the defaults file
	[defaults setBool:preserveBackups forKey:@"PreserveBackups"];	// bug: this puts 1 or 0 into the defaults file rather than YES or NO
	[defaults setBool:autosave forKey:@"Autosave"];
	[defaults setInteger:autosaveInterval forKey:@"AutosaveInterval"];
	[defaults setBool:deleteResourceWarning forKey:@"DeleteResourceWarning"];
	[defaults synchronize];
}

- (IBAction)cancelPrefs:(id)sender
{
	// load saved defaults
	NSUserDefaults*	defaults	= [NSUserDefaults standardUserDefaults];
	BOOL preserveBackups		= [defaults boolForKey:@"PreserveBackups"];
	BOOL autosave				= [defaults boolForKey:@"Autosave"];
	int autosaveInterval		= [defaults integerForKey:@"AutosaveInterval"];
	BOOL deleteResourceWarning	= [defaults boolForKey:@"DeleteResourceWarning"];
	
	// hide the window
	[[self window] orderOut:nil];
	
	// and reset dialog to match
	[[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] setState:preserveBackups];
	[[dataProtectionMatrix cellAtRow:autosaveBox column:0] setState:autosave];
	[autosaveIntervalField setStringValue:[NSString stringWithFormat:@"%d", autosaveInterval]];
	[[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] setState:deleteResourceWarning];
}

- (IBAction)resetToDefault:(id)sender
{
	// reset prefs window widgets to values stored in defaults.plist file
	NSDictionary *defaultsPlist	= [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]];
	BOOL preserveBackups		= [[defaultsPlist objectForKey:@"PreserveBackups"] intValue]? YES:NO;	// bug: this always evaluates to NO, even if the object in the dictionary is YES
	BOOL autosave				= [[defaultsPlist objectForKey:@"Autosave"] intValue]? YES:NO;
	int autosaveInterval		= [[defaultsPlist objectForKey:@"AutosaveInterval"] intValue];
	BOOL deleteResourceWarning	= [[defaultsPlist objectForKey:@"DeleteResourceWarning"] intValue]? YES:NO;
	
	// note that this function does not modify the user defaults - the user still has to accept or cancel the panel
	[[dataProtectionMatrix cellAtRow:preserveBackupsBox column:0] setState:preserveBackups];
	[[dataProtectionMatrix cellAtRow:autosaveBox column:0] setState:autosave];
	[autosaveIntervalField setStringValue:[NSString stringWithFormat:@"%d", autosaveInterval]];
	[[dataProtectionMatrix cellAtRow:deleteResourceWarningBox column:0] setState:deleteResourceWarning];
}

+ (id)sharedPrefsWindowController
{
	static PrefsWindowController *sharedPrefsWindowController = nil;
	
	if( !sharedPrefsWindowController )
	{
		sharedPrefsWindowController = [[PrefsWindowController allocWithZone:[self zone]] init];
	}
	return sharedPrefsWindowController;
}

@end
