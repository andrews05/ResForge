#import <Cocoa/Cocoa.h>

@interface FindSheetController : NSWindowController
@property (weak) IBOutlet NSButton	*cancelButton;
@property (weak) IBOutlet NSButton	*findNextButton;
@property (weak) IBOutlet NSButton	*replaceAllButton;
@property (weak) IBOutlet NSTextField	*findText;
@property (weak) IBOutlet NSTextField	*replaceText;

@property (weak) IBOutlet NSButton	*startAtTopBox;
@property (weak) IBOutlet NSButton	*wrapAroundBox;
@property (weak) IBOutlet NSButton	*searchBackwardsBox;
@property (weak) IBOutlet NSButton	*searchSelectionOnlyBox;
@property (weak) IBOutlet NSButton	*caseSensitiveBox;
@property (weak) IBOutlet NSButton	*matchEntireWordsBox;
@property (weak) IBOutlet NSMatrix	*searchASCIIOrHexRadios;


- (IBAction)showFindSheet:(id)sender;
- (IBAction)hideFindSheet:(id)sender;

- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)findWithSelection:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)replaceFindNext:(id)sender;

@end
