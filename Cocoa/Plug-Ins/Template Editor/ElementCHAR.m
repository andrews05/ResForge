#import "ElementCHAR.h"
#import "ElementPSTR.h"

#define SIZE_ON_DISK (1)

@implementation ElementCHAR

- (void)readDataFrom:(ResourceStream *)stream
{
    char tmp;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    self.charCode = tmp;
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    char tmp = self.charCode;
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)value
{
    char tmp = self.charCode;
    return [NSString stringWithCString:&tmp encoding:NSMacOSRomanStringEncoding];
}

- (void)setValue:(NSString *)value
{
    // CHAR is allowed to be null
    self.charCode = value.length ? [value cStringUsingEncoding:NSMacOSRomanStringEncoding][0] : 0;
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
