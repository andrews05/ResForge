#import "ElementFBYT.h"

// implements FBYT, FWRD, FLNG, FLLG
@implementation ElementFBYT
@synthesize length;
@dynamic stringValue;

- (id)initForType:(NSString *)t withLabel:(NSString *)l
{
	if (self = [super initForType:t withLabel:l]) {
		if ([t isEqualToString:@"FBYT"])
			length = 1;
		else if ([t isEqualToString:@"FWRD"])
			length = 2;
		else if ([t isEqualToString:@"FLNG"])
			length = 4;
		else if ([t isEqualToString:@"FLLG"])
			length = 8;
		else
			length = 0;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ElementFBYT *element = [super copyWithZone:zone];
	[element setLength:length];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream advanceAmount:length pad:NO];
}

- (unsigned int)sizeOnDisk
{
	return length;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream advanceAmount:length pad:YES];
}

- (NSString *)stringValue
{
	return @"";
}

- (void)setStringValue:(NSString *)str
{
}

- (NSString *)label
{
	if(length) return @"";
	return [super label];
}

- (BOOL)editable
{
	return NO;
}

@end
