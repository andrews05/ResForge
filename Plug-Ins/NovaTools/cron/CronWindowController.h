#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

#define startField		[activationForm cellAtIndex:0]
#define endField		[activationForm cellAtIndex:1]

@interface CronWindowController : NovaWindowController
{
	IBOutlet NSTextField	*startDayField;
	IBOutlet NSTextField	*startMonthField;
	IBOutlet NSTextField	*startYearField;
	IBOutlet NSStepper		*startDayStepper;
	IBOutlet NSStepper		*startMonthStepper;
	IBOutlet NSStepper		*startYearStepper;
	
	IBOutlet NSTextField	*endDayField;
	IBOutlet NSTextField	*endMonthField;
	IBOutlet NSTextField	*endYearField;
	IBOutlet NSStepper		*endDayStepper;
	IBOutlet NSStepper		*endMonthStepper;
	IBOutlet NSStepper		*endYearStepper;
	
	IBOutlet NSForm			*activationForm;
	
	// data values
	NSCalendarDate *startDate;
	NSCalendarDate *endDate;
}

- (void)update;
- (IBAction)editStart:(id)sender;
- (IBAction)stepStart:(id)sender;
- (IBAction)editEnd:(id)sender;
- (IBAction)stepEnd:(id)sender;
- (IBAction)editStartField:(id)sender;
- (IBAction)editEndField:(id)sender;

@end
