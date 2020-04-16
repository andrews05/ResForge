#import "ElementFRAC.h"

@implementation ElementFRAC
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementFRAC *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt32 tmp = 0;
	[stream readAmount:sizeof(value) toBuffer:&tmp];
	value = CFSwapInt32BigToHost(tmp);
}

- (unsigned int)sizeOnDisk
{
	return sizeof(value);
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt32 tmp = CFSwapInt32HostToBig(value);
	[stream writeAmount:sizeof(value) fromBuffer:&tmp];
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
