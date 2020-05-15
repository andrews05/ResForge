#import "ElementDLLG.h"

#define SIZE_ON_DISK (8)

@implementation ElementDLLG

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.width = 120;
    }
    return self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
	SInt64 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	self.value = CFSwapInt64BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
	*size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	SInt64 tmp = CFSwapInt64HostToBig(self.value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT64_MIN);
        formatter.maximum = @(INT64_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
