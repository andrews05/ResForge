#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

enum
{
	kMinSpinID = 400,
	kSpinIDRange = 64,
	kMinSoundID = 300,
	kSoundIDRange = 64
};

@interface BoomWindowController : NovaWindowController
{
	BoomRec *boomRec;
	
	IBOutlet NSImageView *imageWell;
	IBOutlet NSComboBox *graphicsField;
	IBOutlet NSComboBox *soundField;
	IBOutlet NSTextField *frameRateField;
	IBOutlet NSButton *soundButton;
	IBOutlet NSButton *playButton;
	
	// stuff
	NSNumber *image;
	NSNumber *sound;
	NSNumber *frameRate;
	BOOL silent;
}

- (void)update;
- (void)controlTextDidChange:(NSNotification *)notification;
- (IBAction)toggleSilence:(id)sender;
- (IBAction)playSound:(id)sender;

@end
