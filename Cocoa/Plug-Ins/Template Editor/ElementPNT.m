#import "ElementPNT.h"
#import "ElementRECT.h"

@implementation ElementPNT
@synthesize h;
@synthesize v;

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementRECT configureFields:@[@"h", @"v"] forElement:self];
}

- (void)readDataFrom:(ResourceStream *)stream
{
    SInt16 tmp = 0;
    [stream readAmount:2 toBuffer:&tmp];
    h = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    v = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 4;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(h);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(v);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
