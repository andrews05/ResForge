#import "FindSheetController.h"
#import "HexWindowController.h"

@implementation FindSheetController

/* FORM DELEGATION METHOD */

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	[self updateStrings];
}

- (void)updateStrings
{
	[findString autorelease];
	[replaceString autorelease];
	
	findString = [[[findReplaceForm cellAtIndex:0] stringValue] copy];
	replaceString = [[[findReplaceForm cellAtIndex:1] stringValue] copy];
}

/* HIDE AND SHOW SHEET */

- (IBAction)showFindSheet:(id)sender
{
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
	[findString autorelease];
	findString = [[NSString string] retain];
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
