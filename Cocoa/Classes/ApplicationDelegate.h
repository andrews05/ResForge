#import <Cocoa/Cocoa.h>

@interface ApplicationDelegate : NSObject
{
}

- (IBAction)showAbout:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)visitSourceforge:(id)sender;
- (IBAction)emailDeveloper:(id)sender;
- (IBAction)showInfo:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (void)initUserDefaults;

@end

@interface NSSavePanel (PackageBrowser)

@end