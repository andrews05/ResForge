/* OpenFileDataSource */

#import <Cocoa/Cocoa.h>

@interface OpenFileDataSource : NSObject
{
	IBOutlet NSTableView *forkTableView;
}
@end

@interface OpenPanelDelegate : NSObject
{
	id originalDelegate;
}
@end

@interface NSSavePanel (ResKnife)
- (NSBrowser *)browser;
@end