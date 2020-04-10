#import "FindSheetController.h"
#import "HexWindowController.h"

@implementation FindSheetController
@synthesize findString;
@synthesize replaceString;

@synthesize cancelButton;
@synthesize findNextButton;
@synthesize findReplaceForm;
@synthesize replaceAllButton;

@synthesize startAtTopBox;
@synthesize wrapAroundBox;
@synthesize searchBackwardsBox;
@synthesize searchSelectionOnlyBox;
@synthesize caseSensitiveBox;
@synthesize matchEntireWordsBox;
@synthesize searchASCIIOrHexRadios;

/* FORM DELEGATION METHOD */

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	[self updateStrings];
}

- (void)updateStrings
{
	self.findString = [[findReplaceForm cellAtIndex:0] stringValue];
	self.replaceString = [[findReplaceForm cellAtIndex:1] stringValue];
}

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
	[NSApp beginSheet:[self window] modalForWindow:[sender window] modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (IBAction)hideFindSheet:(id)sender
{
	[[self window] orderOut:nil];
	[NSApp endSheet:[self window]];
}

- (IBAction)findNext:(id)sender
{
	[self updateStrings];
	[self hideFindSheet:self];
	NSLog( @"Finding next \"%@\"", findString );
}

- (IBAction)findPrevious:(id)sender
{
	[self updateStrings];
	[self hideFindSheet:self];
	NSLog( @"Finding previous \"%@\"", findString );
}

- (IBAction)findWithSelection:(id)sender
{
	findString = [NSString string];
	NSLog( @"Finding \"%@\"", findString );
}

- (IBAction)replaceAll:(id)sender
{
	[self updateStrings];
	[self hideFindSheet:self];
	NSLog( @"Replacing all \"%@\" with \"%@\"", findString, replaceString );
}

- (IBAction)replaceFindNext:(id)sender
{
	[self updateStrings];
	[self hideFindSheet:self];
	NSLog( @"Replacing \"%@\" with \"%@\" and finding next", findString, replaceString );
}

@end
