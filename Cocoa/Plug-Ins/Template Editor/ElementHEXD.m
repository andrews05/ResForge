#import "ElementHEXD.h"

@implementation ElementHEXD
@synthesize value;
@dynamic stringValue;
@synthesize length;
@synthesize lengthBytes = _lengthBytes;
@synthesize skipLengthBytes = _skipLengthBytes;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        value = nil;
        length = 0;
        if ([t isEqualToString:@"BHEX"])    {
            _lengthBytes = 1;
            _skipLengthBytes = NO;
        } else if([t isEqualToString:@"WHEX"]) {
            _lengthBytes = 2;
            _skipLengthBytes = NO;
        } else if ([t isEqualToString:@"LHEX"]) {
            _lengthBytes = 4;
            _skipLengthBytes = NO;
        } else if ([t isEqualToString:@"BSHX"]) {
            _lengthBytes = 1;
            _skipLengthBytes = YES;
        } else if ([t isEqualToString:@"WSHX"]) {
            _lengthBytes = 2;
            _skipLengthBytes = YES;
        } else if ([t isEqualToString:@"LSHX"]) {
            _lengthBytes = 4;
            _skipLengthBytes = YES;
        } else if ([t isEqualToString:@"HEXD"]) {
            _lengthBytes = 0;
            _skipLengthBytes = NO;
        }
        else {
            // Hnnn
            NSScanner *scanner = [NSScanner scannerWithString:[t substringFromIndex:1]];
            [scanner scanHexInt:&length];
            _lengthBytes = 0;
            _skipLengthBytes = NO;
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ElementHEXD *element = [super copyWithZone:zone];
	element.value = value;
    element.length = length;
    element.lengthBytes = _lengthBytes;
    element.skipLengthBytes = _skipLengthBytes;
	return element;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	// override to tell stream to stop reading any more TMPL fields
	if([stream bytesToGo] > 0 && [self.type isEqualToString:@"HEXD"])
	{
		NSLog(@"Warning: Template has fields following hex dump, ignoring them.");
		[stream setBytesToGo:0];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
    // get data length
    if (_lengthBytes > 0) {
        [stream readAmount:_lengthBytes toBuffer:&length];
        length = CFSwapInt32BigToHost(length);
        length >>= (4 - _lengthBytes) << 3;
        if (_skipLengthBytes) length -= _lengthBytes;
    } else if ([self.type isEqualToString:@"HEXD"]) {
        length = [stream bytesToGo];
    }
	[self setValue:[NSData dataWithBytes:[stream data] length:length]];
    [stream advanceAmount:length pad:NO];
}

- (unsigned int)sizeOnDisk
{
	return length + _lengthBytes;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    if (_lengthBytes > 0) {
        UInt32 writeLength = length;
        if (_skipLengthBytes) writeLength += _lengthBytes;
        writeLength <<= (4 - _lengthBytes) << 3;
        writeLength = CFSwapInt32HostToBig(writeLength);
        [stream writeAmount:_lengthBytes fromBuffer:&writeLength];
    }
	[stream writeAmount:length fromBuffer:[value bytes]];
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
