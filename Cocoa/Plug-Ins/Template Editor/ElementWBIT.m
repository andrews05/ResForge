#import "ElementWBIT.h"

#define SIZE_ON_DISK (2)

@implementation ElementWBIT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.position = 16;
    }
    return self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt16 completeValue = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&completeValue];
    completeValue = CFSwapInt16BigToHost(completeValue);
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
    UInt16 completeValue = 0;
    for (ElementBBIT* element in self.bitList) {
        completeValue |= element.value << element.position;
    }
    completeValue = CFSwapInt16HostToBig(completeValue);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&completeValue];
}

@end
