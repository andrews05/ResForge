#import "ElementHEXD.h"

@implementation ElementHEXD

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        _length = 0;
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
            [scanner scanHexInt:&_length];
            _lengthBytes = 0;
            _skipLengthBytes = NO;
        }
    }
    return self;
}

- (void)configureView:(NSView *)view
{
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 3, view.frame.size.width, 17)];
    textField.bezeled = NO;
    textField.editable = NO;
    textField.selectable = YES;
    textField.stringValue = [self.data description] ?: @"<>";
    textField.autoresizingMask = NSViewWidthSizable;
    [view addSubview:textField];
}

- (void)configure
{
    if ([self.type isEqualToString:@"HEXD"] && [self.parentList peek:1]) {
        NSLog(@"Template has fields following hex dump.");
    }
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if ([self.type isEqualToString:@"HEXD"]) {
        // consume all remaining data
        _length = stream.bytesToGo;
        self.data = [NSData dataWithBytes:[stream data] length:_length];
        stream.bytesToGo = 0;
        return;
    }
    // get data length
    if (_lengthBytes > 0) {
        [stream readAmount:_lengthBytes toBuffer:&_length];
        _length = CFSwapInt32BigToHost(_length);
        _length >>= (4 - _lengthBytes) << 3;
        if (_skipLengthBytes && _length > 0) _length -= _lengthBytes;
        if (_length > stream.bytesToGo) _length = stream.bytesToGo;
    }
    char *buffer = malloc(_length);
    [stream readAmount:_length toBuffer:buffer];
    self.data = [NSData dataWithBytesNoCopy:buffer length:_length freeWhenDone:YES];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += _length + _lengthBytes;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if (_lengthBytes > 0) {
        UInt32 writeLength = _length;
        if (_skipLengthBytes) writeLength += _lengthBytes;
        writeLength <<= (4 - _lengthBytes) << 3;
        writeLength = CFSwapInt32HostToBig(writeLength);
        [stream writeAmount:_lengthBytes fromBuffer:&writeLength];
    }
    if (self.data)
        [stream writeAmount:_length fromBuffer:[self.data bytes]];
    else
        [stream advanceAmount:_length pad:YES];
}

@end
