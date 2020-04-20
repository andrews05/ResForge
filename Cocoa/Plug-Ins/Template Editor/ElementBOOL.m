#import "TemplateWindowController.h"
#import "ElementBOOL.h"

#define SIZE_ON_DISK (2)

@implementation ElementBOOL
@synthesize value;

- (id)copyWithZone:(NSZone *)zone
{
    ElementBOOL *element = [super copyWithZone:zone];
    element.value = value;
    return element;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSRect frame = NSMakeRect(0, 0, [tableColumn width], 18);
    NSView *view = [[NSView alloc] initWithFrame:frame];
    
    frame.size.width = 60;
    NSButton *on = [[NSButton alloc] initWithFrame:frame];
    on.buttonType = NSRadioButton;
    on.title = @"True";
    on.action = @selector(itemValueUpdated:);
    [on bind:@"value" toObject:self withKeyPath:@"boolValue" options:nil];
    [view addSubview:on];
    
    frame.origin.x += frame.size.width;
    NSButton *off = [[NSButton alloc] initWithFrame:frame];
    off.buttonType = NSRadioButton;
    off.title = @"False";
    off.action = @selector(itemValueUpdated:);
    [off bind:@"value" toObject:self withKeyPath:@"boolValue" options:@{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    [view addSubview:off];
    
    return view;
}

- (BOOL)boolValue
{
    return value >= 256;
}

- (void)setBoolValue:(BOOL)boolValue
{
    value = boolValue ? 256 : 0;
}

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt16 tmp = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    value = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt16 tmp = CFSwapInt16HostToBig(value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

@end
