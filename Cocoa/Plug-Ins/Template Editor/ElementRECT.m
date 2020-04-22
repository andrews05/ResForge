#import "ElementRECT.h"
#import "ElementDWRD.h"

@implementation ElementRECT
@synthesize top;
@synthesize left;
@synthesize bottom;
@synthesize right;

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementRECT configureFields:@[@"top", @"left", @"bottom", @"right"] forElement:self];
}

+ (NSView *)configureFields:(NSArray *)fields forElement:(Element *)element
{
    NSRect frame = NSMakeRect(0, 0, 56, 18);
    NSTableCellView *view = [[NSTableCellView alloc] initWithFrame:frame];
    NSFont *font = [NSFont systemFontOfSize:13];
    for (NSString *key in fields) {
        NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
        field.bordered = NO;
        field.drawsBackground = NO;
        field.editable = YES;
        field.placeholderString = @"DWRD";
        field.formatter = [ElementDWRD sharedFormatter];
        field.delegate = element;
        field.font = font;
        [field bind:@"value" toObject:element withKeyPath:key options:nil];
        [view addSubview:field];
        frame.origin.x += 60;
    }
    view.textField = view.subviews[0];
    return view;
}

- (void)readDataFrom:(TemplateStream *)stream
{
    SInt16 tmp = 0;
    [stream readAmount:2 toBuffer:&tmp];
    top = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    left = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    bottom = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    right = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 8;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(top);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(left);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(bottom);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(right);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
