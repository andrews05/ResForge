#import "ElementWFLG.h"
#import "ElementBOOL.h"

@implementation ElementWFLG

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBOOL createCheckboxWithFrame:view.frame forElement:self]];
}

@end
