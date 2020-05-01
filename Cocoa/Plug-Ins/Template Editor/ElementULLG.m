#import "ElementULLG.h"

#define SIZE_ON_DISK (8)

@implementation ElementULLG

- (void)readDataFrom:(ResourceStream *)stream
{
	UInt64 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt64BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	UInt64 tmp = CFSwapInt64HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = 0;
        formatter.maximum = @(UINT64_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
