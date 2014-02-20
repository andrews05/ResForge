#import "ElementHEXD.h"

@implementation ElementHEXD

- (id)copyWithZone:(NSZone *)zone
{
	ElementHEXD *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	// override to tell stream to stop reading any more TMPL fields
	if([stream bytesToGo] > 0)
	{
		NSLog(@"Warning: Template has fields following hex dump, ignoring them.");
		[stream setBytesToGo:0];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[self setValue:[NSData dataWithBytes:[stream data] length:[stream bytesToGo]]];
	[stream setBytesToGo:0];
}

- (unsigned int)sizeOnDisk
{
	return [value length];
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:[value length] fromBuffer:[value bytes]];
}

- (void)setValue:(NSData *)d
{
	id old = value;
	value = [d retain];
	[old release];
}

- (NSData *)value
{
	return value;
}

- (NSString *)stringValue
{
	return [value description];
}

- (void)setStringValue:(NSString *)str
{
}

- (BOOL)editable
{
	return NO;
}

@end
