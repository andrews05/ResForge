#import "ElementRECT.h"
#import "ElementDWRD.h"

@implementation ElementRECT

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    return [ElementRECT configureFields:@[@"top", @"left", @"bottom", @"right"] forElement:self];
}

+ (NSTableCellView *)configureFields:(NSArray *)fields forElement:(Element *)element
{
    NSRect frame = NSMakeRect(0, 0, element.width-4, element.rowHeight);
    NSTableCellView *view = [[NSTableCellView alloc] initWithFrame:frame];
    for (NSString *key in fields) {
        NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
        field.placeholderString = key;
        field.formatter = [ElementDWRD sharedFormatter];
        field.delegate = element;
        [field bind:@"value" toObject:element withKeyPath:key options:nil];
        [view addSubview:field];
        frame.origin.x += element.width;
    }
    return view;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    SInt16 tmp;
    [stream readAmount:2 toBuffer:&tmp];
    self.top = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    self.left = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    self.bottom = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    self.right = CFSwapInt16BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += 8;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(self.top);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(self.left);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(self.bottom);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(self.right);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
