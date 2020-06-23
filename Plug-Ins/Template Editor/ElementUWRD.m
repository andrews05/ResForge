#import "ElementUWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementUWRD

- (void)readDataFrom:(ResourceStream *)stream
{
	UInt16 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt16BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	UInt16 tmp = CFSwapInt16HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = 0;
        formatter.maximum = @(UINT16_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
