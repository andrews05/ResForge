#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

#define cashField		[goodiesForm cellAtIndex:0]
#define killsField		[goodiesForm cellAtIndex:1]
#define prefixField		[timeForm cellAtIndex:0]
#define suffixField		[timeForm cellAtIndex:1]
#define statusField1	[statusForm cellAtIndex:0]
#define statusField2	[statusForm cellAtIndex:1]
#define statusField3	[statusForm cellAtIndex:2]
#define statusField4	[statusForm cellAtIndex:3]

@interface CharWindowController : NovaWindowController
{
	IBOutlet NSComboBox *shipField;
	IBOutlet NSForm *goodiesForm;
	
	IBOutlet NSTextField *dayField;
	IBOutlet NSTextField *monthField;
	IBOutlet NSTextField *yearField;
	IBOutlet NSStepper *dayStepper;
	IBOutlet NSStepper *monthStepper;
	IBOutlet NSStepper *yearStepper;
	IBOutlet NSForm *timeForm;
	
	IBOutlet NSComboBox *startField1;
	IBOutlet NSComboBox *startField2;
	IBOutlet NSComboBox *startField3;
	IBOutlet NSComboBox *startField4;
	
	IBOutlet NSForm *statusForm;
	IBOutlet NSComboBox *governmentField1;
	IBOutlet NSComboBox *governmentField2;
	IBOutlet NSComboBox *governmentField3;
	IBOutlet NSComboBox *governmentField4;
	
	// Initial Goodies
	NSNumber *ship;
	NSNumber *cash;
	NSNumber *kills;
	
	// Beginning Of Time
	NSCalendarDate *date;
	NSString *prefix;
	NSString *suffix;
	
	// Starting Location
	NSNumber *start1;
	NSNumber *start2;
	NSNumber *start3;
	NSNumber *start4;
	
	// Governments
	NSNumber *status1;
	NSNumber *status2;
	NSNumber *status3;
	NSNumber *status4;
	NSNumber *government1;
	NSNumber *government2;
	NSNumber *government3;
	NSNumber *government4;
}

- (void)update;
- (IBAction)editDate:(id)sender;
- (IBAction)stepDate:(id)sender;

@end
