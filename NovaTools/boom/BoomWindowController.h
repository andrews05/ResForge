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
}

@property (weak) IBOutlet NSImageView *imageWell;
@property (weak) IBOutlet NSComboBox *graphicsField;
@property (weak) IBOutlet NSComboBox *soundField;
@property (weak) IBOutlet NSTextField *frameRateField;
@property (weak) IBOutlet NSButton *soundButton;
@property (weak) IBOutlet NSButton *playButton;

@property short image;
@property short sound;
@property (strong) NSNumber *frameRate;
@property (getter = isSilent) BOOL silent;

- (void)update;
- (void)controlTextDidChange:(NSNotification *)notification;
- (IBAction)toggleSilence:(id)sender;
- (IBAction)playSound:(id)sender;

@end
