#import "BoomWindowController.h"

@implementation BoomWindowController

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
	silent = (boomRec->SoundIndex == -1);
	image = [[NSNumber alloc] initWithShort:boomRec->GraphicIndex + kMinBoomSpinID];
	sound = [[NSNumber alloc] initWithShort:(silent? kMinBoomSoundID : boomRec->SoundIndex + kMinBoomSoundID)];
	frameRate = [[NSNumber alloc] initWithShort:boomRec->FrameAdvance];
	
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
	[imageWell setImage:[[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") resourceOfType:[plugBundle localizedStringForKey:@"spin" value:@"" table:@"Resource Types"] andID:image inDocument:nil] data]] autorelease]];
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
		id old = image;
		image = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![image isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == soundField && [sender stringValue]  )
	{
		id old = sound;
		sound = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![sound isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == frameRateField )
	{
		id old = frameRate;
		frameRate = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![frameRate isEqualToNumber:old] ) [resource touch];
		[old release];
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
	NSData *data = [(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") resourceOfType:[plugBundle localizedStringForKey:@"snd" value:@"" table:@"Resource Types"] andID:sound inDocument:nil] data];
	if( data && [data length] != 0 )
	{
//		SndListPtr sndPtr = (SndListPtr) [data bytes];
//		SndPlay( nil, &sndPtr, false );
		NSSound *nssound = [[[NSSound alloc] initWithData:data] autorelease];
		[nssound play];
	}
	else NSBeep();
}

- (NSDictionary *)validateValues
{
	NSMutableDictionary *errorValues = [NSMutableDictionary dictionary];
	
	// put current values into boomRec
	boomRec->GraphicIndex = [image shortValue] - kMinBoomSpinID;
	boomRec->SoundIndex = [sound shortValue] - kMinBoomSoundID;
	boomRec->FrameAdvance = [frameRate shortValue];
	if( silent ) boomRec->SoundIndex = -1;
	
	// verify values are valid
	if( boomRec->GraphicIndex < 0 || boomRec->GraphicIndex > 63 )
		[errorValues setObject:@"must match a spin resource with ID between 400 and 463." forKey:@"Graphics"];
	if( boomRec->SoundIndex < -1 || boomRec->SoundIndex > 63 )
		[errorValues setObject:@"must match a sound resource with ID between 300 and 363." forKey:@"Sound"];
	if( boomRec->FrameAdvance < 1 || boomRec->FrameAdvance > 1000 )
		[errorValues setObject:@"cannot be below 0% or above 1000%." forKey:@"Frame Advance"];
	
	// all values fell within acceptable range
	return errorValues;
}

- (void)saveResource
{
	// save new data into resource structure (should have already been validated, and boomRec filled out correctly)
	[resource setData:[NSData dataWithBytes:boomRec length:sizeof(BoomRec)]];
}

@end
