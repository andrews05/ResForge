#import <Cocoa/Cocoa.h>

@interface OpenPanelDelegate : NSObject <NSOpenSavePanelDelegate>
{
/*!	@var openPanelAccessoryView	Accessory view for <tt>NSOpenPanels</tt>. */
	IBOutlet NSView				*openPanelAccessoryView;
/*!	@var forkTableView			Table view inside <tt>openPanelAccessoryView</tt>. */
	IBOutlet NSTableView		*forkTableView;
/*!	@var addForkButton			Button for adding forks to a file. */
	IBOutlet NSButton			*addForkButton;
/*!	@var removeForkButton		Button for removing forks from a file. */
	IBOutlet NSButton			*removeForkButton;
	
/*!	@var forks					Array of forks representing the currently selected file. */
	NSMutableArray *forks;
/*!	@var readOpenPanelForFork	Flag indicating whether ResKnife should ask for a fork to parse in a secondary dialog (false) or obtain it from the selected item in the open dialog (true). */
	BOOL readOpenPanelForFork;
}

/* actions from aux view controls */

- (IBAction)addFork:(id)sender;
- (IBAction)removeFork:(id)sender;

/* accessors */

/*!
@method			openPanelAccessoryView
@abstract		Accessor method for the <tt>openPanelAccessoryView</tt> instance variable.
*/
- (NSView *)openPanelAccessoryView;

/*!
@method			forkTableView
@abstract		Accessor method for the <tt>forkTableView</tt> instance variable.
*/
- (NSTableView *)forkTableView;

- (NSArray *)forks;
- (void)setReadOpenPanelForFork:(BOOL)flag;
- (BOOL)readOpenPanelForFork;

@end