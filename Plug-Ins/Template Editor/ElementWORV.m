#import "ElementWORV.h"
#import "ElementCASE.h"

#define SIZE_ON_DISK (2)

@implementation ElementWORV

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt16 value;
    [stream readAmount:SIZE_ON_DISK toBuffer:&value];
    value = CFSwapInt16BigToHost(value);
    for (int i = 0; i < self.cases.count; i++) {
        ElementCASE *element = self.cases[i];
        UInt32 val = [self.values[i] intValue];
        element.value = (value & val) == val ? @"1" : @"0";
    }
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt16 value = 0;
    for (int i = 0; i < self.cases.count; i++) {
        ElementCASE *element = self.cases[i];
        UInt32 val = [self.values[i] intValue];
        if ([element.value boolValue]) value |= val;
    }
    value = CFSwapInt16HostToBig(value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

@end
