#import "CharWindowController.h"

@implementation CharWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	self = [self initWithWindowNibName:@"char"];
	if( !self ) return nil;
	
	// load data from resource
	charRec = (CharRec *) calloc( 1, sizeof(CharRec) );
	[[newResource data] getBytes:charRec];
	principalChar = charRec->Flags & 0x0001;
	ship = [[NSNumber alloc] initWithShort:charRec->startShipType];	// resID
	cash = [[NSNumber alloc] initWithLong:charRec->startCash];
	kills = [[NSNumber alloc] initWithShort:charRec->startKills];
	date = [[NSCalendarDate alloc] initWithYear:charRec->startYear month:charRec->startMonth day:charRec->startDay hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	prefix = [[NSString alloc] initWithCString:charRec->Prefix length:16];
	suffix = [[NSString alloc] initWithCString:charRec->Suffix length:16];
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
	onStart = [[NSString alloc] initWithCString:charRec->OnStart length:256];
		
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
	[introTextField setDataSource:descriptionDataSource];
	
	// set notifications for ending editing on a combo box
	[localCenter addObserver:self selector:@selector(comboBoxWillPopUp:) name:NSComboBoxWillPopUpNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSComboBoxWillDismissNotification object:nil];
	[localCenter addObserver:self selector:@selector(controlTextDidChange:) name:NSControlTextDidChangeNotification object:nil];
	
	// finally, show the window
	[self update];
	[self showWindow:self];
}

- (void)update
{
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
	if( [start1 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [startField1 setObjectValue:nil];
	else [startField1 setObjectValue:[planetDataSource stringValueForResID:start1]];
	if( [start2 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [startField2 setObjectValue:nil];
	else [startField2 setObjectValue:[planetDataSource stringValueForResID:start2]];
	if( [start3 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [startField3 setObjectValue:nil];
	else [startField3 setObjectValue:[planetDataSource stringValueForResID:start3]];
	if( [start4 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [startField4 setObjectValue:nil];
	else [startField4 setObjectValue:[planetDataSource stringValueForResID:start4]];
	
	// governments
	[statusField1 setObjectValue:status1];
	[statusField2 setObjectValue:status2];
	[statusField3 setObjectValue:status3];
	[statusField4 setObjectValue:status4];
	if( [government1 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [governmentField1 setObjectValue:nil];
	else [governmentField1 setObjectValue:[governmentDataSource stringValueForResID:government1]];
	if( [government2 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [governmentField2 setObjectValue:nil];
	else [governmentField2 setObjectValue:[governmentDataSource stringValueForResID:government2]];
	if( [government3 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [governmentField3 setObjectValue:nil];
	else [governmentField3 setObjectValue:[governmentDataSource stringValueForResID:government3]];
	if( [government4 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [governmentField4 setObjectValue:nil];
	else [governmentField4 setObjectValue:[governmentDataSource stringValueForResID:government4]];
	
	// intro text & pics
	if( [introPict1 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [introPictField1 setObjectValue:nil];
	else [introPictField1 setObjectValue:[governmentDataSource stringValueForResID:government1]];
	if( [introPict2 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [introPictField2 setObjectValue:nil];
	else [introPictField2 setObjectValue:[governmentDataSource stringValueForResID:government2]];
	if( [introPict3 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [introPictField3 setObjectValue:nil];
	else [introPictField3 setObjectValue:[governmentDataSource stringValueForResID:government3]];
	if( [introPict4 isEqualToNumber:[NSNumber numberWithInt:-1]] ) [introPictField4 setObjectValue:nil];
	else [introPictField4 setObjectValue:[governmentDataSource stringValueForResID:government4]];
	if( [introText isEqualToNumber:[NSNumber numberWithInt:-1]] ) [introTextField setObjectValue:nil];
	else [introTextField setObjectValue:[descriptionDataSource stringValueForResID:introText]];
	
	{
		const char *stringData = [[(id <ResKnifeResourceProtocol>)[NSClassFromString(@"Resource") getResourceOfType:[plugBundle localizedStringForKey:@"desc" value:@"" table:@"Resource Types"] andID:introText inDocument:nil] data] bytes];
		if( stringData != NULL )
			[introTextView setString:[NSString stringWithCString:stringData]];
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
	
	if( [sender class] == NSClassFromString(@"NSComboBox") )
		[sender reloadData];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	id sender = [notification object];
	
	/* ship combo box */
	
	if( sender == shipField )
	{
		id old = ship;
		ship = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![ship isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* planet combo boxes */
	
	else if( sender == startField1 )
	{
		id old = start1;
		start1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField2 )
	{
		id old = start2;
		start2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField3 )
	{
		id old = start3;
		start3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == startField4 )
	{
		id old = start4;
		start4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![start4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* government combo boxes */
	
	else if( sender == governmentField1 )
	{
		id old = government1;
		government1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField2 )
	{
		id old = government2;
		government2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField3 )
	{
		id old = government3;
		government3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == governmentField4 )
	{
		id old = government4;
		government4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![government4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	/* planet combo boxes */
	
	else if( sender == introPictField1 )
	{
		id old = introPict1;
		introPict1 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict1 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField2 )
	{
		id old = introPict2;
		introPict2 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict2 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField3 )
	{
		id old = introPict3;
		introPict3 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict3 isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	else if( sender == introPictField4 )
	{
		id old = introPict4;
		introPict4 = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introPict4 isEqualToNumber:old] ) [resource touch];
		[old release];
	}

	/* intro text combo box */
	
	else if( sender == introTextField )
	{
		id old = introText;
		introText = [[DataSource resIDFromStringValue:[sender stringValue]] retain];
		if( ![introText isEqualToNumber:old] ) [resource touch];
		[old release];
	}
	
	// hack to simply & easily parse combo boxes
	[self comboBoxWillPopUp:notification];
	[self setDocumentEdited:[resource isDirty]];
}

@end
