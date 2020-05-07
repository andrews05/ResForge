#import "ElementPACK.h"
#import "ResKnifeResourceProtocol.h"

// The PACK element is an experimental layout control element
// It allows packing multiple subsequent elements, identified by label, into a single row
// This can be helpful for grouping related elements, especially if they may otherwise not be consecutive
// The PACK label format looks like "Display Label=element1Label,element2Label"
@implementation ElementPACK

- (void)configure
{
    self.subElements = [NSMutableArray new];
    NSArray *components = [self.label componentsSeparatedByString:@"="];
    if (components.count > 1) {
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

- (void)configureView:(NSView *)view
{
    for (Element *element in self.subElements) {
        if (element.cases) element.width = 180;
        [element configureView:view];
    }
    CGFloat x = 0;
    for (NSView *subview in view.subviews) {
        NSRect subframe = subview.frame;
        subframe.origin.x = x;
        subview.frame = subframe;
        subview.autoresizingMask |= NSViewMaxXMargin;
        x += subframe.size.width+4;
    }
}

@end
