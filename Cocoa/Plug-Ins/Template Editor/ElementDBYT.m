#import "ElementDBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementDBYT
@synthesize value;

- (void)readDataFrom:(ResourceStream *)stream
{
	[stream readAmount:SIZE_ON_DISK toBuffer:&value];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT8_MIN);
        formatter.maximum = @(INT8_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end

@implementation ElementKBYT
@end
