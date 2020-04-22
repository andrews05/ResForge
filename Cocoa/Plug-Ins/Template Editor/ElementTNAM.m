#import "ElementTNAM.h"
#import "ElementPSTR.h"
#import "ResKnifeResourceProtocol.h"

#define SIZE_ON_DISK (4)

@implementation ElementTNAM
@synthesize tnam;

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt32 tmp = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    tnam = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt32 tmp = CFSwapInt32HostToBig(tnam);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)value
{
    return GetNSStringFromOSType(tnam);
}

- (void)setValue:(NSString *)value
{
    tnam = GetOSTypeFromNSString(value);
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
