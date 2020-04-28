#import "ElementBFLG.h"
#import "TemplateWindowController.h"

@implementation ElementBFLG

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementBFLG configureCheckboxForElement:self];
}

+ (NSView *)configureCheckboxForElement:(Element *)element
{
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)];
    NSButton *checkbox = [ElementBFLG configureCheckboxForElement:element offset:0];
    [view addSubview:checkbox];
    return view;
}

+ (NSButton *)configureCheckboxForElement:(Element *)element offset:(CGFloat)offset
{
    NSButton *checkbox = [[NSButton alloc] initWithFrame:NSMakeRect(offset, 0, 18, 18)];
    checkbox.buttonType = NSSwitchButton;
    checkbox.bezelStyle = NSBezelStyleRegularSquare;
    checkbox.title = @"";
    checkbox.action = @selector(itemValueUpdated:);
    [checkbox bind:@"value" toObject:element withKeyPath:@"value" options:nil];
    return checkbox;
}

@end
