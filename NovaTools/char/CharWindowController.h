#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

#define cashField			[goodiesForm cellAtIndex:0]
#define killsField			[goodiesForm cellAtIndex:1]
#define prefixField			[timeForm cellAtIndex:0]
#define suffixField			[timeForm cellAtIndex:1]
#define statusField1		[statusForm cellAtIndex:0]
#define statusField2		[statusForm cellAtIndex:1]
#define statusField3		[statusForm cellAtIndex:2]
#define statusField4		[statusForm cellAtIndex:3]
#define introDelayField1	[introDelayForm cellAtIndex:0]
#define introDelayField2	[introDelayForm cellAtIndex:1]
#define introDelayField3	[introDelayForm cellAtIndex:2]
#define introDelayField4	[introDelayForm cellAtIndex:3]
#define onStartField		[ncbForm cellAtIndex:0]

@interface CharWindowController : NovaWindowController
{
	CharRec *charRec;
	
	IBOutlet NSButton *principalCharButton;
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
	
	IBOutlet NSComboBox *introPictField1;
	IBOutlet NSComboBox *introPictField2;
	IBOutlet NSComboBox *introPictField3;
	IBOutlet NSComboBox *introPictField4;
	IBOutlet NSForm *introDelayForm;
	IBOutlet NSComboBox *introTextField;
	IBOutlet NSButton *introImageView;		// button so user can click to skip to next pic
	IBOutlet NSTextView *introTextView;
	
	IBOutlet NSForm *ncbForm;
	
	// char
	BOOL principalChar;
	
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
	
	// Introduction
	NSNumber *introText;
	NSNumber *introPict1;
	NSNumber *introPict2;
	NSNumber *introPict3;
	NSNumber *introPict4;
	NSNumber *introDelay1;
	NSNumber *introDelay2;
	NSNumber *introDelay3;
	NSNumber *introDelay4;
	NSTimer *introPictTimer;
	short currentPict;
	
	// Nova Control Bits
	NSString *onStart;
}

- (void)update;
- (IBAction)editDate:(id)sender;
- (IBAction)stepDate:(id)sender;
- (IBAction)togglePrincipalChar:(id)sender;
- (void)rotateIntroPict:(NSTimer *)timer;
- (void)comboBoxWillPopUp:(NSNotification *)notification;
- (void)controlTextDidChange:(NSNotification *)notification;

@end
