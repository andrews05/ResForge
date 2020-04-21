#import "ElementLFLG.h"
#import "ElementBFLG.h"

@implementation ElementLFLG

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementBFLG configureCheckboxForElement:self];
}

@end
