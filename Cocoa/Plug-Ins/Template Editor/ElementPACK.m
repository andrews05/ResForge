#import "ElementPACK.h"
#import "ResKnifeResourceProtocol.h"

// The PACK element is an experimental layout control element
// It allows packing multiple subsequent elements, identified by label, into a single row
// The PACK label format looks like "Display Label=element1Label,element2Label"
@implementation ElementPACK

- (void)configure
{
    NSArray *components = [self.label componentsSeparatedByString:@"="];
    self.label = components[0];
    self.subElements = [NSMutableArray new];
    if (components.count == 2) {
        for (NSString *label in [components[1] componentsSeparatedByString:@","]) {
            Element *element = [self.parentList nextWithLabel:label];
            if (!element) {
                NSLog(@"Element named '%@' not found for PACK.", label);
                continue;
            }
            element.visible = NO;
            [self.subElements addObject:element];
        }
    }
}

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    NSRect frame = NSMakeRect(0, 0, 240, self.rowHeight);
    NSTableCellView *view = [[NSTableCellView alloc] initWithFrame:frame];
    for (Element *element in self.subElements) {
        for (NSView *subview in [[element dataView:outlineView].subviews copy]) {
            NSRect subframe = subview.frame;
            subframe.origin.x = frame.origin.x;
            subframe.size.width = (element.cases ? 180 : element.width) - 4;
            subview.frame = subframe;
            subview.autoresizingMask = NSViewMaxXMargin;
            [view addSubview:subview];
            frame.origin.x += subframe.size.width+4;
        }
    }
    return view;
}

@end
