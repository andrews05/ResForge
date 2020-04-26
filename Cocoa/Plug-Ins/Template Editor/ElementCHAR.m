#import "ElementCHAR.h"
#import "ElementPSTR.h"

#define SIZE_ON_DISK (1)

@implementation ElementCHAR
@synthesize charCode;

- (void)readDataFrom:(ResourceStream *)stream
{
    [stream readAmount:SIZE_ON_DISK toBuffer:&charCode];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&charCode];
}

- (NSString *)value
{
    return [NSString stringWithCString:&charCode encoding:NSMacOSRomanStringEncoding];
}

- (void)setValue:(NSString *)value
{
    // CHAR is allowed to be null
    charCode = value.length ? [value cStringUsingEncoding:NSMacOSRomanStringEncoding][0] : 0;
}

+ (NSFormatter *)sharedFormatter
{
    static MacRomanFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[MacRomanFormatter alloc] init];
        formatter.stringLength = 1;
    }
    return formatter;
}

@end
