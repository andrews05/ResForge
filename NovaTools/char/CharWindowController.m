#import "CharWindowController.h"
#import "Resource.h"

@implementation CharWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	NSString *tempPrefix;
	NSString *tempSuffix;
	NSString *tempStart;
	
	self = [self initWithWindowNibName:@"char"];
	if( !self ) return nil;
	
	// load data from resource
	charRec = (CharRec *) calloc( 1, sizeof(CharRec) );
	[[newResource data] getBytes:charRec];
	
	// fill in default values if necessary
	if( charRec->startYear == 0 || charRec->startMonth == 0 || charRec->startDay == 0 )
	{
		NSCalendarDate *today = [NSCalendarDate calendarDate];
		charRec->startDay = [today dayOfMonth];
		charRec->startMonth = [today monthOfYear];
		charRec->startYear = [today yearOfCommonEra];
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
	principalChar = charRec->Flags & 0x0001;
	ship = [[NSNumber alloc] initWithShort:charRec->startShipType];	// resID
	cash = [[NSNumber alloc] initWithLong:charRec->startCash];
	kills = [[NSNumber alloc] initWithShort:charRec->startKills];
	date = [[NSCalendarDate alloc] initWithYear:charRec->startYear month:charRec->startMonth day:charRec->startDay hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	tempPrefix = [[[NSString alloc] initWithData:[NSData dataWithBytes:charRec->Prefix length:16] encoding:NSMacOSRomanStringEncoding] autorelease];
	prefix = [[NSString alloc] initWithCString:[tempPrefix cString] length:[tempPrefix cStringLength]];
	tempSuffix = [[[NSString alloc] initWithData:[NSData dataWithBytes:charRec->Suffix length:16] encoding:NSMacOSRomanStringEncoding] autorelease];
	suffix = [[NSString alloc] initWithCString:[tempSuffix cString] length:[tempSuffix cStringLength]];
	start1 = [[NSNumber alloc] initWithShort:charRec->startSystem[0]];
	start2 = [[NSNumber alloc] initWithShort:charRec->startSystem[1]];
	start3 = [[NSNumber alloc] initWithShort:charRec->startSystem[2]];
	start4 = [[NSNumber alloc] initWithShort:charRec->startSystem[3]];
	status1 = [[NSNumber alloc] initWithShort:charRec->startStatus[0]];
	status2 = [[NSNumber alloc] initWithShort:charRec->startStatus[1]];
	status3 = [[NSNumber alloc] initWithShort:charRec->startStatus[2]];
	status4 = [[NSNumber alloc] initWithShort:charRec->startStatus[3]];
	government1 = [[NSNumber alloc] initWithShort:charRec->startGovt[0]];
	government2 = [[NSNumber alloc] initWithShort:charRec->startGovt[1]];
	government3 = [[NSNumber alloc] initWithShort:charRec->startGovt[2]];
	government4 = [[NSNumber alloc] initWithShort:charRec->startGovt[3]];
	introText = [[NSNumber alloc] initWithShort:charRec->introTextID];
	introPict1 = [[NSNumber alloc] initWithShort:charRec->introPictID[0]];
	introPict2 = [[NSNumber alloc] initWithShort:charRec->introPictID[1]];
	introPict3 = [[NSNumber alloc] initWithShort:charRec->introPictID[2]];
	introPict4 = [[NSNumber alloc] initWithShort:charRec->introPictID[3]];
	introDelay1 = [[NSNumber alloc] initWithShort:charRec->introPictDelay[0]];
	introDelay2 = [[NSNumber alloc] initWithShort:charRec->introPictDelay[1]];
	introDelay3 = [[NSNumber alloc] initWithShort:charRec->introPictDelay[2]];
	introDelay4 = [[NSNumber alloc] initWithShort:charRec->introPictDelay[3]];
	tempStart = [[[NSString alloc] initWithData:[NSData dataWithBytes:charRec->OnStart length:256] encoding:NSMacOSRomanStringEncoding] autorelease];
	onStart = [[NSString alloc] initWithCString:[tempStart cString] length:[tempStart cStringLength]];
	
	// rotating image
	currentPict = 0;
	
	return self;
}

- (void)dealloc
{
	// bug: release everything
	[super dealloc];
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
	if( ![[resource data] isEqualToData:[NSData dataWithBytes:charRec length:sizeof(CharRec)]] )
	{
		[resource touch];
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
	[principalCharButton setState:principalChar];
	
	// initial goodies
	[shipField setObjectValue:[shipDataSource stringValueForResID:ship]];
	[cashField setObjectValue:cash];
	[killsField setObjectValue:kills];
	
	// beginning of time
	[dayField setObjectValue:date];
	[monthField setObjectValue:date];
	[yearField setObjectValue:date];
	[dayStepper setIntValue:[date dayOfMonth]];
	[monthStepper setIntValue:[date monthOfYear]];
	[yearStepper setIntValue:[date yearOfCommonEra]];
	[prefixField setStringValue:prefix];
	[suffixField setStringValue:suffix];
	
	// starting locations
	[startField1 setObjectValue:[planetDataSource stringValueForResID:start1]];
	[startField2 setObjectValue:[planetDataSource stringValueForResID:start2]];
	[startField3 setObjectValue:[planetDataSource stringValueForResID:start3]];
	[startField4 setObjectValue:[planetDataSource stringValueForResID:start4]];
	
	// governments
	[statusField1 setObjectValue:status1];
	[statusField2 setObjectValue:status2];
	[statusField3 setObjectValue:status3];
	[statusField4 setObjectValue:status4];
	[governmentField1 setObjectValue:[governmentDataSource stringValueForResID:government1]];
	[governmentField2 setObjectValue:[governmentDataSource stringValueForResID:government2]];
	[governmentField3 setObjectValue:[governmentDataSource stringValueForResID:government3]];
	[governmentField4 setObjectValue:[governmentDataSource stringValueForResID:government4]];
	
	// intro text & pics
	[introDelayField1 setObjectValue:introDelay1];
	[introDelayField2 setObjectValue:introDelay2];
	[introDelayField3 setObjectValue:introDelay3];
	[introDelayField4 setObjectValue:introDelay4];
	[introPictField1 setObjectValue:[pictureDataSource stringValueForResID:introPict1]];
	[introPictField2 setObjectValue:[pictureDataSource stringValueForResID:introPict2]];
	[introPictField3 setObjectValue:[pictureDataSource stringValueForResID:introPict3]];
	[introPictField4 setObjectValue:[pictureDataSource stringValueForResID:introPict4]];
	[introTextField setObjectValue:[descriptionDataSource stringValueForResID:introText]];
	
	stringData = [(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"desc" value:@"" table:@"Resource Types"] andID:introText inDocument:nil] data];
	if( stringData != nil )
	{
		[introTextView setString:[[[NSString alloc] initWithData:stringData encoding:NSMacOSRomanStringEncoding] autorelease]];
//		[introTextView scrollToTop];	// bug: made up method - needs implementing
	}
	// ncbs
	[onStartField setStringValue:onStart];
}

- (IBAction)editDate:(id)sender
{
	id old = date;
	date = [[NSCalendarDate alloc] initWithYear:[yearField intValue] month:[monthField intValue] day:[dayField intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[old release];
	[self update];
}

- (IBAction)stepDate:(id)sender
{
	id old = date;
	date = [[NSCalendarDate alloc] initWithYear:[yearStepper intValue] month:[monthStepper intValue] day:[dayStepper intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[old release];
	[self update];
}

- (IBAction)togglePrincipalChar:(id)sender
{
	principalChar = [principalCharButton state];
	[resource touch];
	[self setDocumentEdited:YES];
}

- (IBAction)rotateIntroPictEarly:(id)sender
{
	[introPictTimer fire];
}

- (void)rotateIntroPict:(NSTimer *)timer
{
	// identify next frame
	currentPict++;
	if( currentPict == 2 && [introPict2 intValue] == -1 )		currentPict = 1;
	else if( currentPict == 3 && [introPict3 intValue] == -1 )	currentPict = 1;
	else if( currentPict == 4 && [introPict4 intValue] == -1 )	currentPict = 1;
	else if( currentPict > 4 )									currentPict = 1;
	
	// install new timer
	switch( currentPict )
	{
		case 1:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[introDelay1 doubleValue] target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"PICT" value:@"" table:@"Resource Types"] andID:introPict1 inDocument:nil] data]] autorelease]];
			break;
	
		case 2:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[introDelay2 doubleValue] target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"PICT" value:@"" table:@"Resource Types"] andID:introPict2 inDocument:nil] data]] autorelease]];
			break;
	
		case 3:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[introDelay3 doubleValue] target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"PICT" value:@"" table:@"Resource Types"] andID:introPict3 inDocument:nil] data]] autorelease]];
			break;
	
		case 4:
			// install new timer
			introPictTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)[introDelay4 doubleValue] target:self selector:@selector(rotateIntroPict:) userInfo:nil repeats:NO];
			// set next picture
			[introImageView setImage:[[[NSImage alloc] initWithData:[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"PICT" value:@"" table:@"Resource Types"] andID:introPict4 inDocument:nil] data]] autorelease]];
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
		id old = ship;
		ship = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![ship isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == cashField )
	{
		id old = cash;
		cash = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![cash isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == killsField )
	{
		id old = kills;
		kills = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![kills isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* start date */
	else if( sender == dayField || sender == dayStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[old yearOfCommonEra] month:[old monthOfYear] day:[sender intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [resource touch];
		[old release];
	}
	else if( sender == monthField || sender == monthStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[old yearOfCommonEra] month:[sender intValue] day:[old dayOfMonth] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [resource touch];
		[old release];
	}
	else if( sender == yearField || sender == yearStepper )
	{
		id old = date;
		date = [[NSCalendarDate alloc] initWithYear:[sender intValue] month:[old monthOfYear] day:[old dayOfMonth] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];;
		if( ![date isEqualToDate:old] ) [resource touch];
		[old release];
	}
	else if( sender == prefixField && [sender stringValue] )
	{
		id old = prefix;
		prefix = [[sender stringValue] retain];
		if( ![prefix isEqualToString:old] ) [resource touch];
		[old release];
	}
	else if( sender == suffixField && [sender stringValue] )
	{
		id old = suffix;
		suffix = [[sender stringValue] retain];
		if( ![suffix isEqualToString:old] ) [resource touch];
		[old release];
	}
	
	/* planet combo boxes */
	else if( sender == startField1 && [sender stringValue] )
	{
		id old = start1;
		start1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField2 && [sender stringValue] )
	{
		id old = start2;
		start2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField3 && [sender stringValue] )
	{
		id old = start3;
		start3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField4 && [sender stringValue] )
	{
		id old = start4;
		start4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}

	/* starting government status */
	else if( sender == statusField1 )
	{
		id old = status1;
		status1 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![status1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == statusField2 )
	{
		id old = status2;
		status2 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![status2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == statusField3 )
	{
		id old = status3;
		status3 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![status3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == statusField4 )
	{
		id old = status4;
		status4 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![status4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* government combo boxes */
	else if( sender == governmentField1 && [sender stringValue] )
	{
		id old = government1;
		government1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField2 && [sender stringValue] )
	{
		id old = government2;
		government2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField3 && [sender stringValue] )
	{
		id old = government3;
		government3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField4 && [sender stringValue] )
	{
		id old = government4;
		government4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* intro text combo box */
	else if( sender == introTextField && [sender stringValue] )
	{
		id old = introText;
		introText = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introText isEqualToNumber:old] )
		{
			[resource touch];
			[self update];		// to draw text in text box
		}
		[old release];
	}
	
	/* intro picture combo boxes */
	else if( sender == introPictField1 && [sender stringValue] )
	{
		id old = introPict1;
		introPict1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField2 && [sender stringValue] )
	{
		id old = introPict2;
		introPict2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField3 && [sender stringValue] )
	{
		id old = introPict3;
		introPict3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField4 && [sender stringValue] )
	{
		id old = introPict4;
		introPict4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* intro picture delays */
	else if( sender == introDelayField1 )
	{
		id old = introDelay1;
		introDelay1 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![introDelay1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introDelayField2 )
	{
		id old = introDelay2;
		introDelay2 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![introDelay2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introDelayField3 )
	{
		id old = introDelay3;
		introDelay3 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![introDelay3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introDelayField4 )
	{
		id old = introDelay4;
		introDelay4 = [[NSNumber alloc] initWithInt:[sender intValue]];
		if( ![introDelay4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* on start field */
	else if( sender == onStartField && [sender stringValue] )
	{
		id old = onStart;
		onStart = [[sender stringValue] retain];
		if( ![onStart isEqualToString:old] ) [resource touch];
		[old release];
	}
	
	// hack to simply & easily parse combo boxes
	[self comboBoxWillPopUp:notification];
	[self setDocumentEdited:[resource isDirty]];
}

- (NSDictionary *)validateValues
{
	NSMutableDictionary *errorValues = [NSMutableDictionary dictionary];
	
	// put current values into boomRec
	charRec->Flags = 0x0000;
	charRec->Flags |= principalChar? 0x0001:0;
	charRec->startShipType = [ship shortValue];
	charRec->startCash = [cash longValue];
	charRec->startKills = [kills shortValue];
	charRec->startDay = [date dayOfMonth];
	charRec->startMonth = [date monthOfYear];
	charRec->startYear = [date yearOfCommonEra];
	bzero( charRec->Prefix, 16 );
	memmove( charRec->Prefix, [prefix cString], [prefix cStringLength] <= 15? [prefix cStringLength]+1:16 );
	bzero( charRec->Suffix, 16 );
	memmove( charRec->Suffix, [suffix cString], [suffix cStringLength] <= 15? [suffix cStringLength]+1:16 );
	charRec->startSystem[0] = [start1 shortValue];
	charRec->startSystem[1] = [start2 shortValue];
	charRec->startSystem[2] = [start3 shortValue];
	charRec->startSystem[3] = [start4 shortValue];
	charRec->startGovt[0] = [government1 shortValue];
	charRec->startGovt[1] = [government2 shortValue];
	charRec->startGovt[2] = [government3 shortValue];
	charRec->startGovt[3] = [government4 shortValue];
	charRec->startStatus[0] = [status1 shortValue];
	charRec->startStatus[1] = [status2 shortValue];
	charRec->startStatus[2] = [status3 shortValue];
	charRec->startStatus[3] = [status4 shortValue];
	charRec->introTextID = [introText shortValue];
	charRec->introPictID[0] = [introPict1 shortValue];
	charRec->introPictID[1] = [introPict2 shortValue];
	charRec->introPictID[2] = [introPict3 shortValue];
	charRec->introPictID[3] = [introPict4 shortValue];
	charRec->introPictDelay[0] = [introDelay1 shortValue];
	charRec->introPictDelay[1] = [introDelay2 shortValue];
	charRec->introPictDelay[2] = [introDelay3 shortValue];
	charRec->introPictDelay[3] = [introDelay4 shortValue];
	bzero( charRec->OnStart, 256 );
	memmove( charRec->OnStart, [onStart cString], [onStart cStringLength] <= 255? [onStart cStringLength]+1:256 );
	bzero( charRec->UnusedA, 8*sizeof(short) );
	
	// verify values are valid
	if(charRec->startDay < 1 || charRec->startDay > 31 )
		[errorValues setObject:@"must be between 1 and 31." forKey:@"Start Day"];
	if( charRec->startMonth < 1 || charRec->startMonth > 12 )
		[errorValues setObject:@"must be between 1 and 12." forKey:@"Start Month"];
	if( charRec->startYear < 1 )
		[errorValues setObject:@"must be above zero." forKey:@"Start Year"];
	if(((charRec->introPictDelay[0] < 1 || charRec->introPictDelay[0] > 300) && (charRec->introPictDelay[0] != -1))
	|| ((charRec->introPictDelay[1] < 1 || charRec->introPictDelay[1] > 300) && (charRec->introPictDelay[1] != -1))
	|| ((charRec->introPictDelay[2] < 1 || charRec->introPictDelay[2] > 300) && (charRec->introPictDelay[2] != -1))
	|| ((charRec->introPictDelay[3] < 1 || charRec->introPictDelay[3] > 300) && (charRec->introPictDelay[3] != -1)))
		[errorValues setObject:@"valid delays are 1 to 300 seconds, or -1 for unused values." forKey:@"Intro Picture Delays"];
	
	// all values fell within acceptable range
	return errorValues;
}

- (void)saveResource
{
	// save new data into resource structure (should have already been validated, and charRec filled out correctly)
	[resource setData:[NSData dataWithBytes:charRec length:sizeof(CharRec)]];
}

@end
