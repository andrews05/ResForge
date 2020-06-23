#import "CharWindowController.h"
#import "Resource.h"

@implementation CharWindowController
@synthesize principalChar;

// Initial Goodies
@synthesize ship;
@synthesize cash;
@synthesize kills;

// Beginning Of Time
@synthesize date;
@synthesize prefix;
@synthesize suffix;

// Starting Location
@synthesize start1;
@synthesize start2;
@synthesize start3;
@synthesize start4;

// Governments
@synthesize status1;
@synthesize status2;
@synthesize status3;
@synthesize status4;
@synthesize government1;
@synthesize government2;
@synthesize government3;
@synthesize government4;

// Introduction
@synthesize introText;
@synthesize introPict1;
@synthesize introPict2;
@synthesize introPict3;
@synthesize introPict4;
@synthesize introDelay1;
@synthesize introDelay2;
@synthesize introDelay3;
@synthesize introDelay4;
@synthesize introPictTimer;
@synthesize currentPict;

// Nova Control Bits
@synthesize onStart;

static void BSwapCharRec(CharRec* toSwap)
{
	toSwap->startCash = CFSwapInt32BigToHost(toSwap->startCash);
	toSwap->startShipType = CFSwapInt16BigToHost(toSwap->startShipType);
	dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t i) {
		toSwap->startSystem[i] = CFSwapInt16BigToHost(toSwap->startSystem[i]);
	});
	dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t i) {
		toSwap->startGovt[i] = CFSwapInt16BigToHost(toSwap->startGovt[i]);
	});
	dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t i) {
		toSwap->startStatus[i] = CFSwapInt16BigToHost(toSwap->startStatus[i]);
	});
	toSwap->startKills = CFSwapInt16BigToHost(toSwap->startKills);
	dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t i) {
		toSwap->introPictID[i] = CFSwapInt16BigToHost(toSwap->introPictID[i]);
	});
	dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t i) {
		toSwap->introPictDelay[i] = CFSwapInt16BigToHost(toSwap->introPictDelay[i]);
	});
	toSwap->introTextID = CFSwapInt16BigToHost(toSwap->introTextID);
	toSwap->Flags = CFSwapInt16BigToHost(toSwap->Flags);
	toSwap->startDay = CFSwapInt16BigToHost(toSwap->startDay);
	toSwap->startMonth = CFSwapInt16BigToHost(toSwap->startMonth);
	toSwap->startYear = CFSwapInt16BigToHost(toSwap->startYear);
}

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	NSString *tempPrefix;
	NSString *tempSuffix;
	NSString *tempStart;
	
	self = [self initWithWindowNibName:@"char"];
	if( !self ) return nil;
	
	// load data from resource
	charRec = (CharRec *) calloc( 1, sizeof(CharRec) );
	[[newResource data] getBytes:charRec];
	BSwapCharRec(charRec);
	
	// fill in default values if necessary
	if( charRec->startYear == 0 || charRec->startMonth == 0 || charRec->startDay == 0 )
	{
		NSCalendarDate *today = [NSCalendarDate calendarDate];
		charRec->startDay = (short)[today dayOfMonth];
		charRec->startMonth = (short)[today monthOfYear];
		charRec->startYear = (short)[today yearOfCommonEra];
	}
	
	// set ship to -1 if unused
	if( charRec->startShipType == 0 )		charRec->startShipType = -1;
	
	// set unused starting locations to -1
	if( charRec->startSystem[0] == 0 )		charRec->startSystem[0] = -1;
	if( charRec->startSystem[1] == 0 )		charRec->startSystem[1] = -1;
	if( charRec->startSystem[2] == 0 )		charRec->startSystem[2] = -1;
	if( charRec->startSystem[3] == 0 )		charRec->startSystem[3] = -1;
	
	// set unused governments to -1
	if( charRec->startGovt[0] == 0 )		charRec->startGovt[0] = -1;
	if( charRec->startGovt[1] == 0 )		charRec->startGovt[1] = -1;
	if( charRec->startGovt[2] == 0 )		charRec->startGovt[2] = -1;
	if( charRec->startGovt[3] == 0 )		charRec->startGovt[3] = -1;
	
	// set unused government's status' to -1
	if( charRec->startGovt[0] == -1 )		charRec->startStatus[0] = -1;
	if( charRec->startGovt[1] == -1 )		charRec->startStatus[1] = -1;
	if( charRec->startGovt[2] == -1 )		charRec->startStatus[2] = -1;
	if( charRec->startGovt[3] == -1 )		charRec->startStatus[3] = -1;
	
	// set unused intro text to -1
	if( charRec->introTextID == 0 )			charRec->introTextID = -1;
	
	// set unused intro picts to -1
	if( charRec->introPictID[0] == 0 )		charRec->introPictID[0] = -1;
	if( charRec->introPictID[1] == 0 )		charRec->introPictID[1] = -1;
	if( charRec->introPictID[2] == 0 )		charRec->introPictID[2] = -1;
	if( charRec->introPictID[3] == 0 )		charRec->introPictID[3] = -1;
	
	// set unused/invalid intro pict delays to -1
	if( charRec->introPictDelay[0] < 1 || charRec->introPictDelay[0] > 300 )
		charRec->introPictDelay[0] = -1;
	if( charRec->introPictDelay[1] < 1 || charRec->introPictDelay[1] > 300 )
		charRec->introPictDelay[1] = -1;
	if( charRec->introPictDelay[2] < 1 || charRec->introPictDelay[2] > 300 )
		charRec->introPictDelay[2] = -1;
	if( charRec->introPictDelay[3] < 1 || charRec->introPictDelay[3] > 300 )
		charRec->introPictDelay[3] = -1;
	
	// use resource values to create NS objects
	self.principalChar = charRec->Flags & 0x0001;
	self.ship = charRec->startShipType;	// resID
	self.cash = charRec->startCash;
	self.kills = charRec->startKills;
	self.date = [[NSCalendarDate alloc] initWithYear:charRec->startYear month:charRec->startMonth day:charRec->startDay hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	tempPrefix = [[NSString alloc] initWithData:[NSData dataWithBytes:charRec->Prefix length:16] encoding:NSMacOSRomanStringEncoding];
	self.prefix = tempPrefix;
	tempSuffix = [[NSString alloc] initWithData:[NSData dataWithBytes:charRec->Suffix length:16] encoding:NSMacOSRomanStringEncoding];
	self.suffix = tempSuffix;
	self.start1 = charRec->startSystem[0];
	self.start2 = charRec->startSystem[1];
	self.start3 = charRec->startSystem[2];
	self.start4 = charRec->startSystem[3];
	self.status1 = charRec->startStatus[0];
	self.status2 = charRec->startStatus[1];
	self.status3 = charRec->startStatus[2];
	self.status4 = charRec->startStatus[3];
	self.government1 = charRec->startGovt[0];
	self.government2 = charRec->startGovt[1];
	self.government3 = charRec->startGovt[2];
	self.government4 = charRec->startGovt[3];
	self.introText = charRec->introTextID;
	self.introPict1 = charRec->introPictID[0];
	self.introPict2 = charRec->introPictID[1];
	self.introPict3 = charRec->introPictID[2];
	self.introPict4 = charRec->introPictID[3];
	self.introDelay1 = charRec->introPictDelay[0];
	self.introDelay2 = charRec->introPictDelay[1];
	self.introDelay3 = charRec->introPictDelay[2];
	self.introDelay4 = charRec->introPictDelay[3];
	tempStart = [[NSString alloc] initWithData:[NSData dataWithBytes:charRec->OnStart length:256] encoding:NSMacOSRomanStringEncoding];
	self.onStart = tempStart;
	
	// rotating image
	self.currentPict = 0;
	
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
		
	// set combo box data sources
	[shipField setDelegate:shipDataSource];
	[shipField setDataSource:shipDataSource];
	[startField1 setDelegate:planetDataSource];
	[startField1 setDataSource:planetDataSource];
	[startField2 setDelegate:planetDataSource];
	[startField2 setDataSource:planetDataSource];
	[startField3 setDelegate:planetDataSource];
	[startField3 setDataSource:planetDataSource];
	[startField4 setDelegate:planetDataSource];
	[startField4 setDataSource:planetDataSource];
	[governmentField1 setDelegate:governmentDataSource];
	[governmentField1 setDataSource:governmentDataSource];
	[governmentField2 setDelegate:governmentDataSource];
	[governmentField2 setDataSource:governmentDataSource];
	[governmentField3 setDelegate:governmentDataSource];
	[governmentField3 setDataSource:governmentDataSource];
	[governmentField4 setDelegate:governmentDataSource];
	[governmentField4 setDataSource:governmentDataSource];
	[introPictField1 setDelegate:pictureDataSource];
	[introPictField1 setDataSource:pictureDataSource];
	[introPictField2 setDelegate:pictureDataSource];
	[introPictField2 setDataSource:pictureDataSource];
	[introPictField3 setDelegate:pictureDataSource];
	[introPictField3 setDataSource:pictureDataSource];
	[introPictField4 setDelegate:pictureDataSource];
	[introPictField4 setDataSource:pictureDataSource];
	[introTextField setDelegate:descriptionDataSource];
	[introTextField setDataSource:descriptionDataSource];
	
	// set notifications for ending editing on a combo box
	[localCenter addObserver:self selector:@selector(comboBoxWillPopUp:) name:NSComboBoxWillPopUpNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSComboBoxWillDismissNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSControlTextDidChangeNotification object:nil];
	
	// mark window changed if initial values were invalid
	if( ![[self.resource data] isEqualToData:[NSData dataWithBytes:charRec length:sizeof(CharRec)]] )
	{
		[self.resource touch];
		[self setDocumentEdited:YES];
	}
	
	// set initial picture
	[self rotateIntroPict:nil];
	
	// finally, show the window
	[self update];
	[self showWindow:self];
}

- (void)update
{
	NSData *stringData;
	
	// principal character
	[principalCharButton setState:self.principalChar];
	
	// initial goodies
	[shipField setObjectValue:[shipDataSource stringValueForResID:ship]];
	[cashField setIntegerValue:cash];
	[killsField setIntegerValue:kills];
	
	// beginning of time
	[dayField setObjectValue:date];
	[monthField setObjectValue:date];
	[yearField setObjectValue:date];
	[dayStepper setIntegerValue:[date dayOfMonth]];
	[monthStepper setIntegerValue:[date monthOfYear]];
	[yearStepper setIntegerValue:[date yearOfCommonEra]];
	[prefixField setStringValue:prefix];
	[suffixField setStringValue:suffix];
	
	// starting locations
	[startField1 setObjectValue:[planetDataSource stringValueForResID:start1]];
	[startField2 setObjectValue:[planetDataSource stringValueForResID:start2]];
	[startField3 setObjectValue:[planetDataSource stringValueForResID:start3]];
	[startField4 setObjectValue:[planetDataSource stringValueForResID:start4]];
	
	// governments
	[statusField1 setIntegerValue:status1];
	[statusField2 setIntegerValue:status2];
	[statusField3 setIntegerValue:status3];
	[statusField4 setIntegerValue:status4];
	[governmentField1 setObjectValue:[governmentDataSource stringValueForResID:government1]];
	[governmentField2 setObjectValue:[governmentDataSource stringValueForResID:government2]];
	[governmentField3 setObjectValue:[governmentDataSource stringValueForResID:government3]];
	[governmentField4 setObjectValue:[governmentDataSource stringValueForResID:government4]];
	
	// intro text & pics
	[introDelayField1 setIntValue:introDelay1];
	[introDelayField2 setIntValue:introDelay2];
	[introDelayField3 setIntValue:introDelay3];
	[introDelayField4 setIntValue:introDelay4];
	[introPictField1 setObjectValue:[pictureDataSource stringValueForResID:introPict1]];
	[introPictField2 setObjectValue:[pictureDataSource stringValueForResID:introPict2]];
	[introPictField3 setObjectValue:[pictureDataSource stringValueForResID:introPict3]];
	[introPictField4 setObjectValue:[pictureDataSource stringValueForResID:introPict4]];
	[introTextField setObjectValue:[descriptionDataSource stringValueForResID:introText]];
	
	stringData = [(id <ResKnifeResource>)[NSClassFromString(@"Resource") getResourceOfType:GetOSTypeFromNSString([plugBundle localizedStringForKey:@"desc" value:@"" table:@"Resource Types"]) andID:introText inDocument:nil] data];
	if( stringData != nil )
	{
		[introTextView setString:[[NSString alloc] initWithData:stringData encoding:NSMacOSRomanStringEncoding]];
		// [introTextView scrollToTop];	// bug: made up method - needs implementing
	}
	// ncbs
	[onStartField setStringValue:onStart];
}

- (IBAction)editDate:(id)sender
{
	date = [[NSCalendarDate alloc] initWithYear:[yearField intValue] month:[monthField intValue] day:[dayField intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)stepDate:(id)sender
{
	date = [[NSCalendarDate alloc] initWithYear:[yearStepper intValue] month:[monthStepper intValue] day:[dayStepper intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)togglePrincipalChar:(id)sender
{
	self.principalChar = [principalCharButton state] ? YES : NO;
	[self.resource touch];
	[self setDocumentEdited:YES];
}

- (IBAction)rotateIntroPictEarly:(id)sender
{
	[introPictTimer fire];
}

- (void)rotateIntroPict:(NSTimer *)timer
{
	// identify next frame
	self.currentPict++;
	if( self.currentPict == 2 && self.introPict2 == -1 )		currentPict = 1;
	else if( currentPict == 3 && introPict3 == -1 )	currentPict = 1;
	else if( currentPict == 4 && introPict4 == -1 )	currentPict = 1;
	else if( currentPict > 4 )									currentPict = 1;
	
	// install new timer
	switch( currentPict )
	{
		case 1:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:introDelay1 target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[NSImage alloc] initWithData:[(id <ResKnifeResource>)[NSClassFromString(@"Resource") getResourceOfType:'PICT' andID:introPict1 inDocument:nil] data]]];
			break;
	
		case 2:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:introDelay2 target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[NSImage alloc] initWithData:[(id <ResKnifeResource>)[NSClassFromString(@"Resource") getResourceOfType:'PICT' andID:introPict2 inDocument:nil] data]]];
			break;
	
		case 3:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:introDelay3 target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[NSImage alloc] initWithData:[(id <ResKnifeResource>)[NSClassFromString(@"Resource") getResourceOfType:'PICT' andID:introPict3 inDocument:nil] data]]];
			break;
	
		case 4:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:introDelay4 target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[NSImage alloc] initWithData:[(id <ResKnifeResource>)[NSClassFromString(@"Resource") getResourceOfType:'PICT' andID:introPict4 inDocument:nil] data]]];
			break;
	
	}
}

- (void)comboBoxWillPopUp:(NSNotification *)notification
{
	id sender = [notification object];
	if( sender == shipField )
		[shipDataSource parseForString:[sender stringValue] sorted:YES];
	else if( sender == startField1 || sender == startField2 || sender == startField3 || sender == startField4 )
		[planetDataSource parseForString:[sender stringValue] sorted:YES];
	else if( sender == governmentField1 || sender == governmentField2 || sender == governmentField3 || sender == governmentField4 )
		[governmentDataSource parseForString:[sender stringValue] sorted:YES];
	else if( sender == introPictField1 || sender == introPictField2 || sender == introPictField3 || sender == introPictField4 )
		[pictureDataSource parseForString:[sender stringValue] sorted:YES];
	else if( sender == introTextField )
		[descriptionDataSource parseForString:[sender stringValue] sorted:YES];
	
	if( [sender class] == [NSComboBox class] )
		[sender reloadData];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	// get the control or form cell being changed
	id sender = [notification object];
	if( [sender class] == [NSForm class] )
		sender = [sender cellAtIndex:[sender indexOfSelectedItem]];
	
	/* ship, cash, kills */
	if( sender == shipField && [sender stringValue] )
	{
		short old = ship;
		ship = [DataSource resIDFromStringValue:[sender stringValue]];
		if (ship != old)
			[self.resource touch];
	}
	else if( sender == cashField )
	{
		int old = cash;
		cash = [sender intValue];
		if (cash != old)
			[self.resource touch];
	}
	else if( sender == killsField )
	{
		short old = kills;
		kills = (short)[sender intValue];
		if (kills != old)
			[self.resource touch];
	}
	
	/* start date */
	else if( sender == dayField || sender == dayStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[old yearOfCommonEra] month:[old monthOfYear] day:[sender intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [self.resource touch];
	}
	else if( sender == monthField || sender == monthStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[old yearOfCommonEra] month:[sender intValue] day:[old dayOfMonth] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [self.resource touch];
	}
	else if( sender == yearField || sender == yearStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[sender intValue] month:[old monthOfYear] day:[old dayOfMonth] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [self.resource touch];
	}
	else if( sender == prefixField && [sender stringValue] )
	{
		id old = prefix;
		prefix = [sender stringValue];
		if( ![prefix isEqualToString:old] ) [self.resource touch];
	}
	else if( sender == suffixField && [sender stringValue] )
	{
		id old = suffix;
		suffix = [sender stringValue];
		if( ![suffix isEqualToString:old] ) [self.resource touch];
	}
	
	/* planet combo boxes */
	else if( sender == startField1 && [sender stringValue] )
	{
		short old = start1;
		start1 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (start1 !=old)
			[self.resource touch];
	}
	else if( sender == startField2 && [sender stringValue] )
	{
		short old = start2;
		start2 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (start2 != old)
			[self.resource touch];
	}
	else if( sender == startField3 && [sender stringValue] )
	{
		short old = start3;
		start3 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (start3 != old)
			[self.resource touch];
	}
	else if( sender == startField4 && [sender stringValue] )
	{
		short old = start4;
		start4 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (start4 != old)
			[self.resource touch];
	}

	/* starting government status */
	else if( sender == statusField1 )
	{
		short old = status1;
		status1 = (short)[sender intValue];
		if (status1 != old)
			[self.resource touch];
	}
	else if( sender == statusField2 )
	{
		short old = status2;
		status2 = (short)([sender intValue]);
		if (status2 != old)
			[self.resource touch];
	}
	else if( sender == statusField3 )
	{
		short old = status3;
		status3 = (short)([sender intValue]);
		if (status3 != old)
			[self.resource touch];
	}
	else if( sender == statusField4 )
	{
		short old = status4;
		status4 = (short)([sender intValue]);
		if (status4 != old)
			[self.resource touch];
	}
	
	/* government combo boxes */
	else if( sender == governmentField1 && [sender stringValue] )
	{
		short old = government1;
		government1 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (government1 != old)
			[self.resource touch];
	}
	else if( sender == governmentField2 && [sender stringValue] )
	{
		short old = government2;
		government2 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (government2 != old)
			[self.resource touch];
	}
	else if( sender == governmentField3 && [sender stringValue] )
	{
		short old = government3;
		government3 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (government3 != old)
			[self.resource touch];
	}
	else if( sender == governmentField4 && [sender stringValue] )
	{
		short old = government4;
		government4 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (government4 != old)
			[self.resource touch];
	}
	
	/* intro text combo box */
	else if( sender == introTextField && [sender stringValue] )
	{
		short old = introText;
		introText = [DataSource resIDFromStringValue:[sender stringValue]];
		if (introText != old) {
			[self.resource touch];
			[self update];		// to draw text in text box
		}
	}
	
	/* intro picture combo boxes */
	else if( sender == introPictField1 && [sender stringValue] )
	{
		short old = introPict1;
		introPict1 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (introPict1 != old)
			[self.resource touch];
	}
	else if( sender == introPictField2 && [sender stringValue] )
	{
		short old = introPict2;
		introPict2 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (introPict2 != old)
			[self.resource touch];
	}
	else if( sender == introPictField3 && [sender stringValue] )
	{
		short old = introPict3;
		introPict3 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (introPict3 != old)
			[self.resource touch];
	}
	else if( sender == introPictField4 && [sender stringValue] )
	{
		short old = introPict4;
		introPict4 = [DataSource resIDFromStringValue:[sender stringValue]];
		if (introPict4 != old)
			[self.resource touch];
	}
	
	/* intro picture delays */
	else if( sender == introDelayField1 )
	{
		int old = introDelay1;
		introDelay1 = (short)[sender intValue];
		if (introDelay1 != old)
			[self.resource touch];
	}
	else if( sender == introDelayField2 )
	{
		int old = introDelay2;
		introDelay2 = (short)[sender intValue];
		if (introDelay2 != old)
			[self.resource touch];
	}
	else if( sender == introDelayField3 )
	{
		int old = introDelay3;
		introDelay3 = (short)[sender intValue];
		if (introDelay3 != old)
			[self.resource touch];
	}
	else if( sender == introDelayField4 )
	{
		int old = introDelay4;
		introDelay4 = (short)[sender intValue];
		if (introDelay4 != old)
			[self.resource touch];
	}
	
	/* on start field */
	else if( sender == onStartField && [sender stringValue] )
	{
		id old = onStart;
		onStart = [sender stringValue];
		if( ![onStart isEqualToString:old] ) [self.resource touch];
	}
	
	// hack to simply & easily parse combo boxes
	[self comboBoxWillPopUp:notification];
	[self setDocumentEdited:[self.resource isDirty]];
}

- (NSDictionary *)validateValues
{
	NSMutableDictionary *errorValues = [NSMutableDictionary dictionary];
	
	// put current values into boomRec
	charRec->Flags = 0x0000;
	charRec->Flags |= principalChar? 0x0001:0;
	charRec->startShipType = ship;
	charRec->startCash = cash;
	charRec->startKills = kills;
	charRec->startDay = (short)[date dayOfMonth];
	charRec->startMonth = (short)[date monthOfYear];
	charRec->startYear = (short)[date yearOfCommonEra];
	bzero( charRec->Prefix, 16 );
	memmove( charRec->Prefix, [prefix cStringUsingEncoding:NSMacOSRomanStringEncoding], [prefix lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding] <= 15? [prefix lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding]+1:16 );
	bzero( charRec->Suffix, 16 );
	memmove( charRec->Suffix, [suffix cStringUsingEncoding:NSMacOSRomanStringEncoding], [suffix lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding] <= 15? [suffix lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding]+1:16 );
	charRec->startSystem[0] = start1;
	charRec->startSystem[1] = start2;
	charRec->startSystem[2] = start3;
	charRec->startSystem[3] = start4;
	charRec->startGovt[0] = government1;
	charRec->startGovt[1] = government2;
	charRec->startGovt[2] = government3;
	charRec->startGovt[3] = government4;
	charRec->startStatus[0] = status1;
	charRec->startStatus[1] = status2;
	charRec->startStatus[2] = status3;
	charRec->startStatus[3] = status4;
	charRec->introTextID = introText;
	charRec->introPictID[0] = introPict1;
	charRec->introPictID[1] = introPict2;
	charRec->introPictID[2] = introPict3;
	charRec->introPictID[3] = introPict4;
	charRec->introPictDelay[0] = introDelay1;
	charRec->introPictDelay[1] = introDelay2;
	charRec->introPictDelay[2] = introDelay3;
	charRec->introPictDelay[3] = introDelay4;
	bzero( charRec->OnStart, 256 );
	memmove( charRec->OnStart, [onStart cStringUsingEncoding:NSMacOSRomanStringEncoding], [onStart lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding] <= 255? [onStart lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding]+1:256 );
	bzero( charRec->UnusedA, 8*sizeof(short) );
	
	// verify values are valid
	if(charRec->startDay < 1 || charRec->startDay > 31 )
		errorValues[@"Start Day"] = @"must be between 1 and 31.";
	if( charRec->startMonth < 1 || charRec->startMonth > 12 )
		errorValues[@"Start Month"] = @"must be between 1 and 12.";
	if( charRec->startYear < 1 )
		errorValues[@"Start Year"] = @"must be above zero.";
	if(((charRec->introPictDelay[0] < 1 || charRec->introPictDelay[0] > 300) && (charRec->introPictDelay[0] != -1))
	|| ((charRec->introPictDelay[1] < 1 || charRec->introPictDelay[1] > 300) && (charRec->introPictDelay[1] != -1))
	|| ((charRec->introPictDelay[2] < 1 || charRec->introPictDelay[2] > 300) && (charRec->introPictDelay[2] != -1))
	|| ((charRec->introPictDelay[3] < 1 || charRec->introPictDelay[3] > 300) && (charRec->introPictDelay[3] != -1)))
		errorValues[@"Intro Picture Delays"] = @"valid delays are 1 to 300 seconds, or -1 for unused values.";
	
	// all values fell within acceptable range
	return errorValues;
}

- (void)saveResource
{
	// save new data into resource structure (should have already been validated, and charRec filled out correctly)
	NSMutableData *saveData = [NSMutableData dataWithBytes:charRec length:sizeof(CharRec)];
	BSwapCharRec([saveData mutableBytes]);
	[self.resource setData:saveData];
}

@end
