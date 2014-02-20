#import "ElementDLNG.h"

@implementation ElementDLNG

- (id)copyWithZone:(NSZone *)zone
{
	ElementDLNG *element = [super copyWithZone:zone];
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

- (void)setValue:(SInt32)v
{
	value = v;
}

- (SInt32)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%ld", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cString], 255);
	value = strtol(cstr, &endPtr, 10);
}

@end

@implementation ElementKLNG
@end
