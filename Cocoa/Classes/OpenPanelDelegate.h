#import <Cocoa/Cocoa.h>

@interface OpenPanelDelegate : NSObject <NSOpenSavePanelDelegate>
@property IBOutlet NSTableView *forkTableView;
@property IBOutlet NSView *openPanelAccessoryView;
@property IBOutlet NSButton *addForkButton;
@property IBOutlet NSButton *removeForkButton;
@property NSMutableArray *forks; // Array of forks representing the currently selected file
// Flag indicating whether ResKnife should ask for a fork to parse in a secondary dialog (false) or obtain it from the selected item in the open dialog (true)
@property BOOL readOpenPanelForFork;

/* actions from aux view controls */

- (IBAction)addFork:(id)sender;
- (IBAction)removeFork:(id)sender;

@end
