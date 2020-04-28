#import "ElementLBIT.h"

#define SIZE_ON_DISK (4)

@implementation ElementLBIT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.compact = YES;
        self.position = 32;
        if ([t isEqualToString:@"LBIT"]) {
            self.bits = 1;
        } else {
            // LBnn
            self.bits = [[t substringFromIndex:2] intValue];
        }
    }
    return self;
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

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    if (!self.bitList) return 0;
    return SIZE_ON_DISK;
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
