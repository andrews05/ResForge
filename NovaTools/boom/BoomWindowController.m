#import "BoomWindowController.h"

@implementation BoomWindowController
@synthesize image;
@synthesize sound;
@synthesize frameRate;
@synthesize silent;
@synthesize imageWell;
@synthesize graphicsField;
@synthesize soundField;
@synthesize frameRateField;
@synthesize soundButton;
@synthesize playButton;

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	self = [self initWithWindowNibName:@"boom"];
	if( !self ) return nil;
	
	boomRec = (BoomRec *) calloc( 1, sizeof(BoomRec) );
	[[newResource data] getBytes:boomRec];
	
	// fill in default values if necessary
	if( boomRec->GraphicIndex < 0 || boomRec->GraphicIndex > 63 )
		boomRec->GraphicIndex = 0;
	if( (boomRec->SoundIndex < 0 || boomRec->SoundIndex > 63) && (boomRec->SoundIndex != -1) )
		boomRec->SoundIndex = 0;
	if( boomRec->FrameAdvance < 1 || boomRec->FrameAdvance > 1000 )
		boomRec->FrameAdvance = 100;
	
	// use resource values to create NS objects
	self.silent = (boomRec->SoundIndex == -1);
	self.image = boomRec->GraphicIndex + kMinBoomSpinID;
	self.sound = (self.silent? kMinBoomSoundID : boomRec->SoundIndex + kMinBoomSoundID);
	self.frameRate = [[NSNumber alloc] initWithShort:boomRec->FrameAdvance];
	
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// set combo box data sources
	[graphicsField setDelegate:spinDataSource];
	[graphicsField setDataSource:spinDataSource];
	[soundField setDelegate:soundDataSource];
	[soundField setDataSource:soundDataSource];
	
	// set notifications for ending editing on a combo box
	[localCenter addObserver:self selector:@selector(comboBoxWillPopUp:) name:NSComboBoxWillPopUpNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSComboBoxWillDismissNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSControlTextDidChangeNotification object:nil];
	
	// mark window changed if initial values were invalid
	if( ![[resource data] isEqualToData:[NSData dataWithBytes:boomRec length:sizeof(BoomRec)]] )
	{
		[resource touch];
		[self setDocumentEdited:YES];
	}
	
	[self update];
	[self showWindow:self];
}

- (void)update
{
	// graphics
	[graphicsField setObjectValue:[spinDataSource stringValueForResID:image]];
	[frameRateField setObjectValue:frameRate];
	
	// sound
	[soundField setObjectValue:[soundDataSource stringValueForResID:sound]];
	[soundButton setState:!silent];
	[soundField setEnabled:!silent];
	[playButton setEnabled:!silent];
	
	// image well
	[imageWell setImage:[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") resourceOfType:GetOSTypeFromNSString([plugBundle localizedStringForKey:@"spin" value:@"" table:@"Resource Types"]) andID:self.image inDocument:nil] data]]];
}

- (void)comboBoxWillPopUp:(NSNotification *)notification
{
	id sender = [notification object];
	if( sender == graphicsField )
		[spinDataSource parseForString:[sender stringValue] withinRange:NSMakeRange(kMinBoomSpinID, kBoomSpinIDRange) sorted:YES];
	else if( sender == soundField )
		[soundDataSource parseForString:[sender stringValue] withinRange:NSMakeRange(kMinBoomSoundID, kBoomSoundIDRange) sorted:YES];
	
	if( [sender class] == [NSComboBox class] )
		[sender reloadData];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	id sender = [notification object];
	if( sender == graphicsField && [sender stringValue] )
	{
		short old = image;
		image = [DataSource resIDFromStringValue:[sender stringValue]];
		if (image != old)
			[resource touch];
	}
	else if( sender == soundField && [sender stringValue]  )
	{
		short old = sound;
		sound = [DataSource resIDFromStringValue:[sender stringValue]];
		if (sound != old)
			[resource touch];
	}
	else if( sender == frameRateField )
	{
		id old = frameRate;
		frameRate = @([sender intValue]);
		if( ![frameRate isEqualToNumber:old] ) [resource touch];
	}
	
	// hack to simply & easily parse combo boxes
	[self comboBoxWillPopUp:notification];
	[self setDocumentEdited:[resource isDirty]];
}

- (IBAction)toggleSilence:(id)sender
{
	silent = ![soundButton state];
	[soundField setEnabled:!silent];
	[playButton setEnabled:!silent];
	[resource touch];
	[self setDocumentEdited:YES];
}

- (IBAction)playSound:(id)sender
{
	NSData *data = [(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") resourceOfType:GetOSTypeFromNSString([plugBundle localizedStringForKey:@"snd" value:@"" table:@"Resource Types"]) andID:sound inDocument:nil] data];
	if( data && [data length] != 0 )
	{
		//SndListPtr sndPtr = (SndListPtr) [data bytes];
		//SndPlay( nil, &sndPtr, false );
		NSSound *nssound = [[NSSound alloc] initWithData:data];
		[nssound play];
	}
	else NSBeep();
}

- (NSDictionary *)validateValues
{
	NSMutableDictionary *errorValues = [NSMutableDictionary dictionary];
	
	// put current values into boomRec
	boomRec->GraphicIndex = image - kMinBoomSpinID;
	boomRec->SoundIndex = sound - kMinBoomSoundID;
	boomRec->FrameAdvance = [frameRate shortValue];
	if( silent ) boomRec->SoundIndex = -1;
	
	// verify values are valid
	if( boomRec->GraphicIndex < 0 || boomRec->GraphicIndex > 63 )
		errorValues[@"Graphics"] = @"must match a spin resource with ID between 400 and 463.";
	if( boomRec->SoundIndex < -1 || boomRec->SoundIndex > 63 )
		errorValues[@"Sound"] = @"must match a sound resource with ID between 300 and 363.";
	if( boomRec->FrameAdvance < 1 || boomRec->FrameAdvance > 1000 )
		errorValues[@"Frame Advance"] = @"cannot be below 0% or above 1000%.";
	
	// all values fell within acceptable range
	return errorValues;
}

- (void)saveResource
{
	// save new data into resource structure (should have already been validated, and boomRec filled out correctly)
	[resource setData:[NSData dataWithBytes:boomRec length:sizeof(BoomRec)]];
}

@end
