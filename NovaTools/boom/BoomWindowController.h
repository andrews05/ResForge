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
	
#ifndef __LP64__
	NSImageView *imageWell;
	NSComboBox *graphicsField;
	NSComboBox *soundField;
	NSTextField *frameRateField;
	NSButton *soundButton;
	NSButton *playButton;
	
	// stuff
	short image;
	short sound;
	NSNumber *frameRate;
	BOOL silent;
#endif
}

@property (assign) IBOutlet NSImageView *imageWell;
@property (assign) IBOutlet NSComboBox *graphicsField;
@property (assign) IBOutlet NSComboBox *soundField;
@property (assign) IBOutlet NSTextField *frameRateField;
@property (assign) IBOutlet NSButton *soundButton;
@property (assign) IBOutlet NSButton *playButton;

@property short image;
@property short sound;
@property (retain) NSNumber *frameRate;
@property (getter = isSilent) BOOL silent;

- (void)update;
- (void)controlTextDidChange:(NSNotification *)notification;
- (IBAction)toggleSilence:(id)sender;
- (IBAction)playSound:(id)sender;

@end
