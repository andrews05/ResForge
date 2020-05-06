#import "ElementDVDR.h"

@implementation ElementDVDR

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.rowHeight = l.length ? 17 : 1;
    }
    return self;
}

- (void)configureGroupView:(NSTableCellView *)view
{
    view.textField.stringValue = self.displayLabel;
}

@end
