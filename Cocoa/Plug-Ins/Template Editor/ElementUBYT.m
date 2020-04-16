#import "ElementUBYT.h"

#define SIZE_ON_DISK (1)

@implementation ElementUBYT
@synthesize value;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementUBYT *element = [super copyWithZone:zone];
	element.value = value;
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream readAmount:SIZE_ON_DISK toBuffer:&value];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%hhu", value];
}

- (void)setStringValue:(NSString *)str
{
	char cstr[256];
	char *endPtr = cstr + 255;
	strncpy(cstr, [str cStringUsingEncoding:NSMacOSRomanStringEncoding], 255);
	value = (UInt8)strtoul(cstr, &endPtr, 10);
}

@end
