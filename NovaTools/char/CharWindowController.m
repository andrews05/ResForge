#import "CharWindowController.h"

@implementation CharWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"char"];
	if( !self ) return nil;
	
	// load data from resource
	ship = [[NSNumber alloc] initWithShort:128];
	cash = [[NSNumber alloc] initWithLong:10000];
	kills = [[NSNumber alloc] initWithUnsignedLong:0];
	
	date = [[NSCalendarDate date] retain];
	prefix = [[NSString alloc] init];
	suffix = [[NSString alloc] init];
	
	start1 = [[NSNumber alloc] initWithShort:128];
	start2 = [[NSNumber alloc] initWithShort:129];
	start3 = [[NSNumber alloc] initWithShort:130];
	start4 = [[NSNumber alloc] initWithShort:131];
	
	status1 = [[NSNumber alloc] initWithShort:0];
	status2 = [[NSNumber alloc] initWithShort:0];
	status3 = [[NSNumber alloc] initWithShort:0];
	status4 = [[NSNumber alloc] initWithShort:0];
	government1 = [[NSNumber alloc] initWithShort:128];
	government2 = [[NSNumber alloc] initWithShort:129];
	government3 = [[NSNumber alloc] initWithShort:130];
	government4 = [[NSNumber alloc] initWithShort:131];
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	
	// set notifications for ending editing on a combo box
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:shipField];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:startField1];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:startField2];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:startField3];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:startField4];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:governmentField1];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:governmentField2];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:governmentField3];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSControlTextDidEndEditingNotification object:governmentField4];
	
	// finally, show the window
	[self update];
	[self showWindow:self];
}

- (void)update
{
	// initial goodies
	[shipField setObjectValue:[shipDataSource stringValueForResID:ship]];
	[shipDataSource parseForString:[shipField stringValue] sorted:NO];
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
	
	// starting location
	[startField1 setObjectValue:[shipDataSource stringValueForResID:start1]];
	[shipDataSource parseForString:[shipField stringValue] sorted:NO];
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

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	if( [notification object] == shipField )
	{
		id old = ship;
		NSString *string = [[notification object] stringValue];
		NSRange range = [string rangeOfString:@"{" options:NSBackwardsSearch];
		range.length = [string length] - range.location++ - 2;
		ship = [[NSNumber alloc] initWithInt:[[string substringWithRange:range] intValue]];
		NSLog( @"Old ship: %@ New ship: %@", old, ship );
		[old release];
	}
	else if( [notification object] == startField1 )
	{
		id old = start1;
		NSString *string = [[notification object] stringValue];
		NSRange range = [string rangeOfString:@"{" options:NSBackwardsSearch];
		range.length = [string length] - range.location++ - 2;
		start1 = [[NSNumber alloc] initWithInt:[[string substringWithRange:range] intValue]];
		NSLog( @"Old start1: %@ New start1: %@", old, start1 );
		[old release];
	}
	else if( [notification object] == startField2 )
	{
		id old = start2;
		NSString *string = [[notification object] stringValue];
		NSRange range = [string rangeOfString:@"{" options:NSBackwardsSearch];
		range.length = [string length] - range.location++ - 2;
		start2 = [[NSNumber alloc] initWithInt:[[string substringWithRange:range] intValue]];
		NSLog( @"Old start2: %@ New start2: %@", old, start2 );
		[old release];
	}
}

@end
