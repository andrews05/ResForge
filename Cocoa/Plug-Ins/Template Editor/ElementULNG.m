#import "ElementULNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementULNG

- (id)copyWithZone:(NSZone *)zone
{
	ElementULNG *element = [super copyWithZone:zone];
	[element setValue:value];
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

- (void)setValue:(UInt32)v
{
	value = v;
}

- (UInt32)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%u", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = strtoul(cstr, &endPtr, 10);
}

@end
