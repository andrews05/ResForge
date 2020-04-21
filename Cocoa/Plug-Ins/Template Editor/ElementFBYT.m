#import "ElementFBYT.h"

// implements FBYT, FWRD, FLNG, FLLG
@implementation ElementFBYT
@synthesize length;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
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
        else {
            // Fnnn
            NSScanner *scanner = [NSScanner scannerWithString:[t substringFromIndex:1]];
            [scanner scanHexInt:&length];
        }
	}
	return self;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream advanceAmount:length pad:NO];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	return length;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream advanceAmount:length pad:YES];
}

- (NSString *)label
{
	return @"";
}

@end
