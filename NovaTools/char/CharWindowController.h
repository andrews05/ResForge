#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

#define prefixField		[timeForm cellAtIndex:0]
#define suffixField		[timeForm cellAtIndex:1]

@interface CharWindowController : NovaWindowController
{
	IBOutlet NSTextField *dayField;
	IBOutlet NSTextField *monthField;
	IBOutlet NSTextField *yearField;
	IBOutlet NSStepper *dayStepper;
	IBOutlet NSStepper *monthStepper;
	IBOutlet NSStepper *yearStepper;
	IBOutlet NSForm *timeForm;
	
	// Initial Goodies
	NSDecimalNumber *ship;
	NSDecimalNumber *cash;
	NSDecimalNumber *kills;
	
	// Beginning Of Time
	NSCalendarDate *date;
	NSString *prefix;
	NSString *suffix;
}

- (void)update;
- (IBAction)stepDate:(id)sender;
- (IBAction)editDate:(id)sender;

@end
