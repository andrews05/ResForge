#import "ElementFIXD.h"

@implementation ElementFIXD

- (id)copyWithZone:(NSZone *)zone
{
	ElementFIXD *element = [super copyWithZone:zone];
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

- (void)setValue:(Fixed)v
{
	value = v;
}

- (Fixed)value
{
	return value;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%.3lf", FixedToFloat(value)];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = FloatToFixed(strtof(cstr, &endPtr));
}

@end
