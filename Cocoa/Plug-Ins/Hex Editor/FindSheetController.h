#import <Cocoa/Cocoa.h>

@interface FindSheetController : NSWindowController
{
    IBOutlet NSButton	*cancelButton;
    IBOutlet NSButton	*findNextButton;
    IBOutlet NSForm		*form;
    IBOutlet NSButton	*replaceAllButton;
    IBOutlet NSButton	*replaceFindNextButton;
}

- (IBAction)findNext:(id)sender;
- (IBAction)hideWindow:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)replaceFindNext:(id)sender;

@end
