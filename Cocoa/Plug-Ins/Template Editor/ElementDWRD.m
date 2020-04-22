#import "ElementDWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementDWRD
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt16 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt16 tmp = CFSwapInt16HostToBig(value);
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

@implementation ElementKWRD
@end
