#import "ElementWFLG.h"
#import "ElementBFLG.h"

@implementation ElementWFLG

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementBFLG configureCheckboxForElement:self];
}

@end
