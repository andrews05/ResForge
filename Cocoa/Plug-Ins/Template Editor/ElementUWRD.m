#import "ElementUWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementUWRD
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
	UInt16 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	UInt16 tmp = CFSwapInt16HostToBig(value);
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
