#import "ElementPACK.h"
#import "ElementCaseable.h"
#import "ResKnifeResourceProtocol.h"

/*
 * The PACK element is an experimental layout control element
 * It allows packing multiple subsequent elements, identified by label, into a single row
 * This can be helpful for grouping related elements, especially if they may otherwise not be consecutive
 * The PACK label format looks like "Display Label=element1Label,element2Label"
 */
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

- (CGFloat)rowHeight
{
    CGFloat rowHeight = super.rowHeight;
    for (Element *element in self.subElements) {
        if (element.rowHeight > rowHeight) rowHeight = element.rowHeight;
    }
    return rowHeight;
}

- (void)configureView:(NSView *)view
{
    NSRect orig = view.frame;
    NSRect frame = view.frame;
    for (__kindof Element *element in self.subElements) {
        if (self.subElements.count > 1 && [element isKindOfClass:ElementCaseable.class] && [element cases])
            element.width = 180;
        [element configureView:view];
        frame.origin.x += element.width;
        view.frame = frame;
    }
    view.frame = orig;
}

@end
