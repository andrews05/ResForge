#import "CronWindowController.h"

@implementation CronWindowController

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	self = [self initWithWindowNibName:@"cron"];
	if( !self ) return nil;
	
	// init fields with data from resource
	startDate = [NSCalendarDate date];
	endDate = [[NSCalendarDate date] dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
	
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
/*	[governmentField1 setDelegate:governmentDataSource];
	[governmentField1 setDataSource:governmentDataSource];
	[governmentField2 setDelegate:governmentDataSource];
	[governmentField2 setDataSource:governmentDataSource];
	[governmentField3 setDelegate:governmentDataSource];
	[governmentField3 setDataSource:governmentDataSource];
	[governmentField4 setDelegate:governmentDataSource];
	[governmentField4 setDataSource:governmentDataSource];
*/	
	[self update];
	[self showWindow:self];
}

// date format to get month as single digit:
//	%e/%1m/%Y == 1/1/2000

- (void)update
{
	// activation
	[startDayField		setObjectValue:startDate];
	[startMonthField	setObjectValue:startDate];
	[startYearField		setObjectValue:startDate];
	[startDayStepper	setIntegerValue:[startDate dayOfMonth]];
	[startMonthStepper	setIntegerValue:[startDate monthOfYear]];
	[startYearStepper	setIntegerValue:[startDate yearOfCommonEra]];
	
	[endDayField		setObjectValue:startDate];
	[endMonthField		setObjectValue:startDate];
	[endYearField		setObjectValue:startDate];
	[endDayStepper		setIntegerValue:[endDate dayOfMonth]];
	[endMonthStepper	setIntegerValue:[endDate monthOfYear]];
	[endYearStepper		setIntegerValue:[endDate yearOfCommonEra]];
	
	[startField			setObjectValue:startDate];
	[endField			setObjectValue:startDate];
}

- (IBAction)editStart:(id)sender
{
	startDate = [[NSCalendarDate alloc] initWithYear:[startYearField intValue] month:[startMonthField intValue] day:[startDayField intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)stepStart:(id)sender
{
	startDate = [[NSCalendarDate alloc] initWithYear:[startYearStepper intValue] month:[startMonthStepper intValue] day:[startDayStepper intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)editEnd:(id)sender
{
	endDate = [[NSCalendarDate alloc] initWithYear:[endYearField intValue] month:[endMonthField intValue] day:[endDayField intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)stepEnd:(id)sender
{
	endDate = [[NSCalendarDate alloc] initWithYear:[endYearStepper intValue] month:[endMonthStepper intValue] day:[endDayStepper intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[self update];
}

- (IBAction)editStartField:(id)sender
{
	startDate = [NSCalendarDate dateWithNaturalLanguageString:[startField stringValue]];
	[self update];
}

- (IBAction)editEndField:(id)sender
{
	endDate = [NSCalendarDate dateWithNaturalLanguageString:[endField stringValue]];
	[self update];
}

@end
