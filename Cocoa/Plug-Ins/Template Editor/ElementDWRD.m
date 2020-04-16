#import "ElementDWRD.h"

#define SIZE_ON_DISK (2)

@implementation ElementDWRD
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementDWRD *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt16 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt16 tmp = CFSwapInt16HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
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
