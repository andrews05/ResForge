#import "ElementDBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementDBYT

- (id)copyWithZone:(NSZone *)zone
{
	ElementDBYT *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream readAmount:SIZE_ON_DISK toBuffer:&value];
}

- (unsigned int)sizeOnDisk
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

- (void)setValue:(SInt8)v
{
	value = v;
}

- (SInt8)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%hhd", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (SInt8)strtol(cstr, &endPtr, 10);
}

@end

@implementation ElementKBYT
@end
