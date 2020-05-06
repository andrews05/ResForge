#import "ElementLFLG.h"
#import "ElementBFLG.h"

@implementation ElementLFLG

- (NSView *)configureView:(NSView *)view
{
    [view addSubview:[ElementBFLG createCheckboxWithFrame:view.frame forElement:self]];
    return view;
}

@end
