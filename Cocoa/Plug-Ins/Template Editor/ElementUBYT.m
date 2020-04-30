#import "ElementUBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementUBYT

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt8 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    self.value = tmp;
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt8 tmp = self.value;
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = 0;
        formatter.maximum = @(UINT8_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
