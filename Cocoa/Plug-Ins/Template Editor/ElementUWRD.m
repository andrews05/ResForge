#import "ElementUWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementUWRD

- (id)copyWithZone:(NSZone *)zone
{
	ElementUWRD *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	UInt16 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt16BigToHost(tmp);
}

- (unsigned int)sizeOnDisk
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	UInt16 tmp = CFSwapInt16HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (void)setValue:(UInt16)v
{
	value = v;
}

- (UInt16)value
{
	return value;
}

- (NSString*)stringValue
{
	return [NSString stringWithFormat:@"%hu", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (UInt16)strtoul(cstr, &endPtr, 10);
}

@end
