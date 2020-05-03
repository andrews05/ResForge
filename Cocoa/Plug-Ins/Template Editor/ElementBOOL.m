#import "ElementBOOL.h"

@implementation ElementBOOL

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
