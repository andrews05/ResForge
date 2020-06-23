#import "ElementLBIT.h"

#define SIZE_ON_DISK (4)

@implementation ElementLBIT

+ (unsigned int)length {
    return 32;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt32 completeValue = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&completeValue];
    completeValue = CFSwapInt32BigToHost(completeValue);
    for (ElementBBIT* element in self.bitList) {
        element.value = (completeValue >> element.position) & ((1 << element.bits) - 1);
    }
}

- (void)sizeOnDisk:(UInt32 *)size
{
    if (!self.bitList) return;
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt32 completeValue = 0;
    for (ElementBBIT* element in self.bitList) {
        completeValue |= element.value << element.position;
    }
    completeValue = CFSwapInt32HostToBig(completeValue);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&completeValue];
}

@end
