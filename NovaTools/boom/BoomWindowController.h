#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

enum	// boom defaults
{
	kMinBoomSpinID = 400,
	kBoomSpinIDRange = 64,
	kMinBoomSoundID = 300,
	kBoomSoundIDRange = 64,
	kMinBoomFrameAdvance = 1,
	kBoomFrameAdvanceRange = 1000,
	
	kDefaultBoomSpinID = kMinBoomSpinID,
	kDefaultBoomSoundID = kMinBoomSoundID,
	kDefaultBoomFrameAdvance = 100
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
