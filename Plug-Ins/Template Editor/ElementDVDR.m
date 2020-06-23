#import "ElementDVDR.h"

@implementation ElementDVDR

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.label = l; // Use entire label without separating tooltip
        self.rowHeight = [l componentsSeparatedByString:@"\n"].count * 17;
    }
    return self;
}

- (void)configureGroupView:(NSTableCellView *)view
{
    view.textField.stringValue = self.displayLabel;
}

@end
