#import <Cocoa/Cocoa.h>

enum DataProtection
{
	preserveBackupsBox = 0,
	autosaveBox,
	deleteResourceWarningBox
};

enum LaunchAction
{
	doNothingBox = 0,
	createNewDocumentBox,
	displayOpenPanelBox
};

#define	prefs		[NSUserDefaults standardUserDefaults]

@interface PrefsWindowController : NSWindowController
{
    IBOutlet NSTextField	*autosaveIntervalField;
    IBOutlet NSMatrix		*dataProtectionMatrix;
    IBOutlet NSMatrix		*launchActionMatrix;
}

- (void)updatePrefs:(NSNotification *)notification;
- (IBAction)acceptPrefs:(id)sender;
- (IBAction)cancelPrefs:(id)sender;
- (IBAction)resetToDefault:(id)sender;

+ (id)sharedPrefsWindowController;

@end

@interface NSString (BooleanSupport)

- (BOOL)boolValue;
+ (NSString *)stringWithBool:(BOOL)boolean;

@end