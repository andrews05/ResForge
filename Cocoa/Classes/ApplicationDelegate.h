#import <Cocoa/Cocoa.h>

@interface ApplicationDelegate : NSObject
{
}

- (IBAction)showAbout:(id)sender;
- (IBAction)showInfo:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (void)initUserDefaults;

@end
