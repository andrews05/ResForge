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

extern NSString * const kPreserveBackups;
extern NSString * const kAutosave;
extern NSString * const kAutosaveInterval;
extern NSString * const kDeleteResourceWarning;
extern NSString * const kLaunchAction;
extern NSString * const kOpenUntitledFile;
extern NSString * const kDisplayOpenPanel;
extern NSString * const kNoLaunchOption;

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
