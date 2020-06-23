#import "ElementFRAC.h"

#define SIZE_ON_DISK (4)

@implementation ElementFRAC
@synthesize fractValue;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.width = 90;
    }
    return self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
	Fract tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	fractValue = CFSwapInt32BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	Fract tmp = CFSwapInt32HostToBig(fractValue);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (float)value
{
	return FractToFloat(fractValue);
}

- (void)setValue:(float)value
{
	fractValue = FloatToFract(value);
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 9;
        formatter.minimum = @(-2);
        formatter.maximum = @(2);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
