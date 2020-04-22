#import "ElementUBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementUBYT
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream readAmount:SIZE_ON_DISK toBuffer:&value];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
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
