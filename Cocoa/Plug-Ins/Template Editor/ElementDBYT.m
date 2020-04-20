#import "ElementDBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementDBYT
@synthesize value;

- (id)copyWithZone:(NSZone *)zone
{
	ElementDBYT *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

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

+ (NSFormatter *)formatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.minimum = @(INT8_MIN);
        formatter.maximum = @(INT8_MAX);
    }
    return formatter;
}

@end

@implementation ElementKBYT
@end
