#import "ElementDLLG.h"

@implementation ElementDLLG

- (id)copyWithZone:(NSZone*)zone
{
	ElementDLLG *element = [super copyWithZone:zone];
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

- (void)setValue:(SInt64)v
{
	value = v;
}

- (SInt64)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%lld", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cString], 255);
	value = strtoll(cstr, &endPtr, 10);
}

@end
