#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

@interface DescWindowController : NovaWindowController
{
	IBOutlet NSView *graphicsView;
}

- (IBAction)chooseMovieFile:(id)sender;

@end
