#import "ElementULNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementULNG
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementULNG *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	UInt32 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt32BigToHost(tmp);
}

- (unsigned int)sizeOnDisk
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	UInt32 tmp = CFSwapInt32HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%u", (unsigned int)value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (UInt32)strtoul(cstr, &endPtr, 10);
}

@end
