#import "ElementBFLG.h"
#import "ElementBOOL.h"

@implementation ElementBFLG

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBOOL createCheckboxWithFrame:view.frame forElement:self]];
}

@end
