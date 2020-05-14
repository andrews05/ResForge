#import "ForkInfo.h"
#import <Cocoa/Cocoa.h>

@interface OpenPanelDelegate : NSObject <NSOpenSavePanelDelegate>
@property IBOutlet NSView *openPanelAccessoryView;
@property IBOutlet NSPopUpButton *forkSelect;
@property NSArray *forks; // Array of forks representing the currently selected file
// Flag indicating whether ResKnife should ask for a fork to parse in a secondary dialog (false) or obtain it from the selected item in the open dialog (true)
@property BOOL readOpenPanelForFork;
@property NSInteger forkIndex;
@property NSByteCountFormatter *formatter;

- (ForkInfo *)getSelectedFork;

@end
