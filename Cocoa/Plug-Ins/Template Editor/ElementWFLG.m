#import "ElementWFLG.h"
#import "ElementBFLG.h"

@implementation ElementWFLG

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    return [ElementBFLG configureCheckboxForElement:self];
}

@end
