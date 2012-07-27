#import "ElementDWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementDWRD

- (id)copyWithZone:(NSZone *)zone
{
	ElementDWRD *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt16 tmp;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt16BigToHost(tmp);
}

- (unsigned int)sizeOnDisk
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt16 tmp = CFSwapInt16HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (void)setValue:(SInt16)v
{
	value = v;
}

- (SInt16)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%hd", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (SInt16)strtol(cstr, &endPtr, 10);
}

@end

@implementation ElementKWRD
@end
