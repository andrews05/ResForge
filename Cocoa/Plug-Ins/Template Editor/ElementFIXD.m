#import "ElementFIXD.h"

@implementation ElementFIXD
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementFIXD *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	Fixed tmp = 0;
	[stream readAmount:sizeof(value) toBuffer:&tmp];
	value = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return sizeof(value);
}

- (void)writeDataTo:(TemplateStream *)stream
{
	Fixed tmp = CFSwapInt32HostToBig(value);
	[stream writeAmount:sizeof(value) fromBuffer:&tmp];
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
