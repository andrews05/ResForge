#import <Cocoa/Cocoa.h>

@interface ApplicationDelegate : NSObject
{
}

- (IBAction)showAbout:(id)sender;
- (IBAction)showInfo:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)showCreateResourceSheet:(id)sender;
- (IBAction)openResource:(id)sender;
- (IBAction)playSound:(id)sender;
- (void)initUserDefaults;

@end
