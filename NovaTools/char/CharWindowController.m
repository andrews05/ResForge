#import "CharWindowController.h"

@implementation CharWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"char"];
	if( !self ) return nil;
	
	// load data from resource
	ship = [[NSDecimalNumber alloc] initWithShort:128];
	cash = [[NSDecimalNumber alloc] initWithLong:10000];
	kills = [[NSDecimalNumber alloc] initWithUnsignedLong:0];
	
	date = [[NSCalendarDate date] retain];
	prefix = [[NSString alloc] init];
	suffix = [[NSString alloc] init];
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( [newResource name] && ![[newResource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", [[self window] title], [newResource name]]];
	[self update];
	return self;
}

- (void)update
{
	// update some stuff in the catchall box
	
	
	// update Beginning Of Time
	[dayField setIntValue:[date dayOfMonth]];
	[monthField setIntValue:[date monthOfYear]];
	[yearField setIntValue:[date yearOfCommonEra]];
	[dayStepper setIntValue:[date dayOfMonth]];
	[monthStepper setIntValue:[date monthOfYear]];
	[yearStepper setIntValue:[date yearOfCommonEra]];
	[prefixField setStringValue:prefix];
	[suffixField setStringValue:suffix];
}

- (IBAction)stepDate:(id)sender
{
	id old = date;
	date = [[NSCalendarDate alloc] initWithYear:[yearStepper intValue] month:[monthStepper intValue] day:[dayStepper intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[old release];
	[self update];
}

- (IBAction)editDate:(id)sender
{
	id old = date;
	date = [[NSCalendarDate alloc] initWithYear:[yearField intValue] month:[monthField intValue] day:[dayField intValue] hour:0 minute:0 second:0 timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	[old release];
	[self update];
}

@end
