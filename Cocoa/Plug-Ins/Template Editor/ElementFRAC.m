#import "ElementFRAC.h"

@implementation ElementFRAC

- (id)copyWithZone:(NSZone *)zone
{
	ElementFRAC *element = [super copyWithZone:zone];
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

- (void)setValue:(Fract)v
{
	value = v;
}

- (Fract)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%.10lg", FractToFloat(value)];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = FloatToFract(strtof(cstr, &endPtr));
}

@end
