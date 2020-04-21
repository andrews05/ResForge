#import "ElementDLLG.h"

#define SIZE_ON_DISK (8)

@implementation ElementDLLG
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt64 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt64BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt64 tmp = CFSwapInt64HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT64_MIN);
        formatter.maximum = @(INT64_MAX);
    }
    return formatter;
}

@end
