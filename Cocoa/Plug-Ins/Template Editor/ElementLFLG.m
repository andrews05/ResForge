#import "ElementLFLG.h"

#define SIZE_ON_DISK (4)

@implementation ElementLFLG
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt32 tmp = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    value = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt32 tmp = CFSwapInt32HostToBig(value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

@end
