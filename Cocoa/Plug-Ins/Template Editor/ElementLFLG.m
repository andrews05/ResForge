#import "ElementLFLG.h"
#import "ElementBFLG.h"

@implementation ElementLFLG

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBFLG createCheckboxWithFrame:view.frame forElement:self]];
}

@end
