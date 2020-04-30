#import "ElementULNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementULNG

- (void)readDataFrom:(ResourceStream *)stream
{
	UInt32 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt32BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	UInt32 tmp = CFSwapInt32HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = 0;
        formatter.maximum = @(UINT32_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
