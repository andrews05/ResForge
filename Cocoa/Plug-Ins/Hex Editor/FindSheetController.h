#import <Cocoa/Cocoa.h>

@interface FindSheetController : NSWindowController
{
	IBOutlet NSButton	*cancelButton;
	IBOutlet NSButton	*findNextButton;
	IBOutlet NSForm		*findReplaceForm;
	IBOutlet NSButton	*replaceAllButton;
//	IBOutlet NSButton	*replaceFindNextButton;
	
	IBOutlet NSButton	*startAtTopBox;
	IBOutlet NSButton	*wrapAroundBox;
	IBOutlet NSButton	*searchBackwardsBox;
	IBOutlet NSButton	*searchSelectionOnlyBox;
	IBOutlet NSButton	*caseSensitiveBox;
	IBOutlet NSButton	*matchEntireWordsBox;
	IBOutlet NSMatrix	*searchASCIIOrHexRadios;
	
	NSString *findString;
	NSString *replaceString;
}

- (void)updateStrings;

- (IBAction)showFindSheet:(id)sender;
- (IBAction)hideFindSheet:(id)sender;

- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)findWithSelection:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)replaceFindNext:(id)sender;

@end
