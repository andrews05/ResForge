#import "ElementULLG.h"

#define SIZE_ON_DISK (8)

@implementation ElementULLG
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone*)zone
{
	ElementULLG *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	UInt64 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt64BigToHost(tmp);
}

- (unsigned int)sizeOnDisk
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	UInt64 tmp = CFSwapInt64HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%llu", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = strtoull(cstr, &endPtr, 10);
}

@end
