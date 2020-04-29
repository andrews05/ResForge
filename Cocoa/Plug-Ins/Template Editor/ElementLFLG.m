#import "ElementLFLG.h"
#import "ElementBFLG.h"

@implementation ElementLFLG

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    return [ElementBFLG configureCheckboxForElement:self];
}

@end
