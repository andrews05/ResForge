#import "ElementUBYT.h"

@implementation ElementUBYT

- (id)copyWithZone:(NSZone *)zone
{
	ElementUBYT *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream readAmount:sizeof(value) toBuffer:&value];
}

- (unsigned int)sizeOnDisk
{
	return sizeof(value);
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:sizeof(value) fromBuffer:&value];
}

- (void)setValue:(UInt8)v
{
	value = v;
}

- (UInt8)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%hhu", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cString], 255);
	value = strtoul(cstr, &endPtr, 10);
}

@end
