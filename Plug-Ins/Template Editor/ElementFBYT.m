#import "ElementFBYT.h"

// implements FBYT, FWRD, FLNG, FLLG
@implementation ElementFBYT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
		if ([t isEqualToString:@"FBYT"])
			_length = 1;
		else if ([t isEqualToString:@"FWRD"])
			_length = 2;
		else if ([t isEqualToString:@"FLNG"])
			_length = 4;
		else if ([t isEqualToString:@"FLLG"])
			_length = 8;
        else {
            // Fnnn
            NSScanner *scanner = [NSScanner scannerWithString:[t substringFromIndex:1]];
            [scanner scanHexInt:&_length];
        }
	}
	return self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
	[stream advanceAmount:_length pad:NO];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += _length;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	[stream advanceAmount:_length pad:YES];
}

- (NSString *)label
{
	return @"";
}

@end
