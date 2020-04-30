#import "ElementTNAM.h"
#import "ElementPSTR.h"
#import "ResKnifeResourceProtocol.h"

#define SIZE_ON_DISK (4)

@implementation ElementTNAM

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt32 tmp;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    self.tnam = CFSwapInt32BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt32 tmp = CFSwapInt32HostToBig(self.tnam);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)value
{
    return GetNSStringFromOSType(self.tnam);
}

- (void)setValue:(NSString *)value
{
    self.tnam = GetOSTypeFromNSString(value);
}

+ (NSFormatter *)sharedFormatter
{
    static MacRomanFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[MacRomanFormatter alloc] init];
        formatter.stringLength = 4;
        formatter.exactLengthRequired = YES;
    }
    return formatter;
}

@end
