#import "ElementLFLG.h"
#import "ElementBOOL.h"

@implementation ElementLFLG

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBOOL createCheckboxWithFrame:view.frame forElement:self]];
}

@end
