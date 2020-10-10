#import "ElementBOOL.h"
#import "Template_Editor-Swift.h"

@implementation ElementBOOL

- (void)configureView:(NSView *)view
{
    [view addSubview:[ElementBOOL createCheckboxWithFrame:view.frame forElement:self]];
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
    if (frame.size.width > 20)
        checkbox.autoresizingMask = NSViewWidthSizable;
    return checkbox;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt8 tmp;
    [stream readAmount:1 toBuffer:&tmp];
    self.value = tmp;
    [stream advanceAmount:1 pad:NO];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += 2;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt8 tmp = self.value;
    [stream writeAmount:1 fromBuffer:&tmp];
    [stream advanceAmount:1 pad:YES];
}

@end
