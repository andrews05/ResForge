#import "ElementDWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementDWRD

- (void)readDataFrom:(ResourceStream *)stream
{
	SInt16 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt16BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
	*size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	SInt16 tmp = CFSwapInt16HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT16_MIN);
        formatter.maximum = @(INT16_MAX);
        formatter.nilSymbol = @"\0"; // Not sure why this is necessary but it prevents crash on blank value
    }
    return formatter;
}

@end
