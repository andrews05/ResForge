#import "ElementREAL.h"

#define SIZE_ON_DISK (4)

@implementation ElementREAL

- (void)readDataFrom:(ResourceStream *)stream
{
    CFSwappedFloat32 tmp;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    self.value = CFConvertFloatSwappedToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    CFSwappedFloat32 tmp = CFConvertFloatHostToSwapped(self.value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.numberStyle = NSNumberFormatterScientificStyle;
        formatter.maximumSignificantDigits = 7;
        formatter.minimum = 0;
        formatter.maximum = @(FLT_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
