#import "TemplateWindowController.h"
#import "ElementBFLG.h"

#define SIZE_ON_DISK (1)

@implementation ElementBFLG
@synthesize value;

- (id)copyWithZone:(NSZone *)zone
{
    ElementBFLG *element = [super copyWithZone:zone];
    element.value = value;
    return element;
}

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

- (void)readDataFrom:(TemplateStream *)stream
{
    [stream readAmount:SIZE_ON_DISK toBuffer:&value];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

@end
