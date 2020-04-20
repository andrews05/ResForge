#import "ElementDLNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementDLNG
@synthesize value;

- (id)copyWithZone:(NSZone *)zone
{
	ElementDLNG *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt32 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt32 tmp = CFSwapInt32HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)formatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT32_MIN);
        formatter.maximum = @(INT32_MAX);
    }
    return formatter;
}

@end

@implementation ElementKLNG
@end
