#import "ElementDLNG.h"

#define SIZE_ON_DISK (4)

@implementation ElementDLNG
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementDLNG *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	SInt32 tmp = 0;
	[stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
	value = CFSwapInt32BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	SInt32 tmp = CFSwapInt32HostToBig(value);
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%d", (int)value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (SInt32)strtol(cstr, &endPtr, 10);
}

@end

@implementation ElementKLNG
@end
