#import "ElementWFLG.h"
#import "ElementBFLG.h"

@implementation ElementWFLG

- (NSView *)configureView:(NSView *)view
{
    [view addSubview:[ElementBFLG createCheckboxWithFrame:view.frame forElement:self]];
    return view;
}

@end
