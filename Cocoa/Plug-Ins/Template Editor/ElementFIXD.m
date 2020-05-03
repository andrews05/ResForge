#import "ElementFIXD.h"

#define SIZE_ON_DISK (4)

@implementation ElementFIXD
@synthesize fixedValue;

- (void)readDataFrom:(ResourceStream *)stream
{
	Fixed tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	fixedValue = CFSwapInt32BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	Fixed tmp = CFSwapInt32HostToBig(fixedValue);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (float)value
{
	return FixedToFloat(fixedValue);
}

- (void)setValue:(float)value
{
	fixedValue = FloatToFixed(value);
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 5;
        formatter.minimum = @(-32768);
        formatter.maximum = @(32768);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
