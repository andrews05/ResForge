#import "ElementHEXD.h"

@implementation ElementHEXD
@synthesize data;
@synthesize length;
@synthesize lengthBytes = _lengthBytes;
@synthesize skipLengthBytes = _skipLengthBytes;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        data = nil;
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

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSTableCellView *view = [outlineView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    view.textField.stringValue = [data description];
    return view;
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
        if (_skipLengthBytes && length > 0) length -= _lengthBytes;
    } else if ([self.type isEqualToString:@"HEXD"]) {
        length = [stream bytesToGo];
    }
    // FIXME: This will fail if there's not enough data in the stream (i.e. new resource with Hnnn field)
	data = [NSData dataWithBytes:[stream data] length:length];
    [stream advanceAmount:length pad:NO];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
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
	[stream writeAmount:length fromBuffer:[data bytes]];
}

@end
