#import "ElementFRAC.h"

#define SIZE_ON_DISK (4)

@implementation ElementFRAC
@synthesize fractValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementFRAC *element = [super copyWithZone:zone];
	element.fractValue = fractValue;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	Fract tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	fractValue = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
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

+ (NSFormatter *)formatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 10;
        formatter.minimum = @(-2);
        formatter.maximum = @(2);
    }
    return formatter;
}

@end
