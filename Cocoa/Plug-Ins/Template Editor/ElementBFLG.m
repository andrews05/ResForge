#import "ElementBFLG.h"
#import "TemplateWindowController.h"

@implementation ElementBFLG

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBFLG createCheckboxWithFrame:view.frame forElement:self]];
}

+ (NSButton *)createCheckboxWithFrame:(NSRect)frame forElement:(Element *)element
{
    NSButton *checkbox = [[NSButton alloc] initWithFrame:frame];
    checkbox.buttonType = NSSwitchButton;
    checkbox.bezelStyle = NSBezelStyleRegularSquare;
    // Use the second part of the label as the checkbox title
    NSArray *labelComponents = [element.label componentsSeparatedByString:@"="];
    checkbox.title = labelComponents.count > 1 ? labelComponents[1] : @"\0";
    checkbox.action = @selector(itemValueUpdated:);
    [checkbox bind:@"value" toObject:element withKeyPath:@"value" options:nil];
    checkbox.autoresizingMask = NSViewWidthSizable;
    return checkbox;
}

@end
