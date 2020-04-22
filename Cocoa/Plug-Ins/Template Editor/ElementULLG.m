#import "ElementULLG.h"

#define SIZE_ON_DISK (8)

@implementation ElementULLG
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
	UInt64 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt64BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	UInt64 tmp = CFSwapInt64HostToBig(value);
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
