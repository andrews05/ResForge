#import "ElementDATE.h"

#define SIZE_ON_DISK (4)

@implementation ElementDATE
@synthesize seconds;

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt32 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    seconds = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt32 tmp = CFSwapInt32HostToBig(seconds);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSDate *)value
{
    CFAbsoluteTime cfTime;
    OSStatus error = UCConvertSecondsToCFAbsoluteTime(seconds, &cfTime);
    if(error) return nil;
    return [NSDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime];

}

- (void)setValue:(NSDate *)value
{
    UCConvertCFAbsoluteTimeToSeconds((CFAbsoluteTime)[value timeIntervalSinceReferenceDate], &seconds);
}

+ (NSFormatter *)sharedFormatter
{
    static NSDateFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterMediumStyle;
    }
    return formatter;
}

@end
