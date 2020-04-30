#import "ElementDLNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementDLNG

- (void)readDataFrom:(ResourceStream *)stream
{
	SInt32 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt32BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
	*size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	SInt32 tmp = CFSwapInt32HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT32_MIN);
        formatter.maximum = @(INT32_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
