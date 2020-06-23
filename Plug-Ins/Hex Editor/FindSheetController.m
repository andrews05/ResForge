#import "FindSheetController.h"
#import "HexWindowController.h"

@implementation FindSheetController

@synthesize cancelButton;
@synthesize findNextButton;
@synthesize replaceAllButton;
@synthesize findText;
@synthesize replaceText;

@synthesize startAtTopBox;
@synthesize wrapAroundBox;
@synthesize searchBackwardsBox;
@synthesize searchSelectionOnlyBox;
@synthesize caseSensitiveBox;
@synthesize matchEntireWordsBox;
@synthesize searchASCIIOrHexRadios;

/* HIDE AND SHOW SHEET */

- (IBAction)showFindSheet:(id)sender
{
	// load window so I can play with boxes
	[self window];
	
	// enable/disable boxes
	[searchSelectionOnlyBox setEnabled:([[[[(HexWindowController *)sender textView] controller] selectedContentsRanges][0] HFRange].length != 0)];
	
	// set inital values
	if( ![searchSelectionOnlyBox isEnabled] )	[searchSelectionOnlyBox setIntValue:0];
	
	// show sheet
	[[sender window] beginSheet:self.window completionHandler:nil];
}

- (IBAction)hideFindSheet:(id)sender
{
	[[self window] orderOut:nil];
	[NSApp endSheet:[self window]];
}

- (IBAction)findNext:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Finding next \"%@\"", findText.stringValue );
}

- (IBAction)findPrevious:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Finding previous \"%@\"", findText.stringValue );
}

- (IBAction)findWithSelection:(id)sender
{
	findText.stringValue = [NSString string];
	NSLog( @"Finding \"%@\"", findText.stringValue );
}

- (IBAction)replaceAll:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Replacing all \"%@\" with \"%@\"", findText.stringValue, replaceText.stringValue );
}

- (IBAction)replaceFindNext:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Replacing \"%@\" with \"%@\" and finding next", findText.stringValue, replaceText.stringValue );
}

@end
