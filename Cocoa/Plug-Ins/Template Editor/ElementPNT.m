#import "ElementPNT.h"
#import "ElementRECT.h"

@implementation ElementPNT
@synthesize top;
@synthesize left;

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    return [ElementRECT configureFields:@[@"top", @"left"] forElement:self];
}

- (void)readDataFrom:(TemplateStream *)stream
{
    SInt16 tmp = 0;
    [stream readAmount:2 toBuffer:&tmp];
    top = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    left = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 4;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(top);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(left);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
