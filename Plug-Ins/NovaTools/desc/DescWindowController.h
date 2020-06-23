#import <Cocoa/Cocoa.h>
#import "NovaWindowController.h"

@interface DescWindowController : NovaWindowController
@property (weak) IBOutlet NSView *graphicsView;

- (IBAction)chooseMovieFile:(id)sender;

@end
