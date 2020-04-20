#import "ElementBFLG.h"
#import "TemplateWindowController.h"

@implementation ElementBFLG

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSRect frame = NSMakeRect(0, 0, 18, 18);
    NSView *view = [[NSView alloc] initWithFrame:frame];
    NSButton *checkbox = [[NSButton alloc] initWithFrame:frame];
    checkbox.buttonType = NSSwitchButton;
    checkbox.title = @"";
    checkbox.action = @selector(itemValueUpdated:);
    [checkbox bind:@"value" toObject:self withKeyPath:@"value" options:nil];
    [view addSubview:checkbox];
    return view;
}

@end
