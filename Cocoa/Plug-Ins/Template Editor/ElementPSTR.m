#import "ElementPSTR.h"

// implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, CHAR, TNAM, Pnnn, Cnnn
@implementation ElementPSTR
@synthesize value;
@synthesize lengthBytes = _lengthBytes;
@synthesize maxLength = _maxLength;
@synthesize minLength = _minLength;
@synthesize pad = _pad;
@synthesize terminatingByte = _terminatingByte;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	if (self = [super initForType:t withLabel:l]) {
		if ([t isEqualToString:@"PSTR"] || [t isEqualToString:@"BSTR"])	{
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_minLength = 0;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if([t isEqualToString:@"WSTR"]) {
			_lengthBytes = 2;
			_maxLength = UINT16_MAX;
			_minLength = 0;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"LSTR"]) {
			_lengthBytes = 4;
			_maxLength = UINT32_MAX;
			_minLength = 0;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"OSTR"]) {
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_minLength = 0;
			_terminatingByte = NO;
			_pad = kPadToOddLength;
		} else if ([t isEqualToString:@"ESTR"]) {
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_minLength = 0;
			_terminatingByte = NO;
			_pad = kPadToEvenLength;
		} else if ([t isEqualToString:@"CSTR"]) {
			_lengthBytes = 0;
			_maxLength = 0;
			_minLength = 0;
			_terminatingByte = YES;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"OCST"]) {
			_lengthBytes = 0;
			_maxLength = 0;
			_minLength = 0;
			_terminatingByte = YES;
			_pad = kPadToOddLength;
		} else if ([t isEqualToString:@"ECST"]) {
			_lengthBytes = 0;
			_maxLength = 0;
			_minLength = 0;
			_terminatingByte = YES;
			_pad = kPadToEvenLength;
		} else if ([t isEqualToString:@"CHAR"]) {
			_lengthBytes = 0;
			_maxLength = 1;
			_minLength = 1;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"TNAM"]) {
			_lengthBytes = 0;
			_maxLength = 4;
			_minLength = 4;
			_terminatingByte = NO;
			_pad = kNoPadding;
		}
		// temp until keyed values are implemented
		else if ([t isEqualToString:@"KCHR"]) {
			_lengthBytes = 0;
			_maxLength = 1;
			_minLength = 1;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"KTYP"]) {
			_lengthBytes = 0;
			_maxLength = 4;
			_minLength = 4;
			_terminatingByte = NO;
			_pad = kNoPadding;
		}
        else {
            // assume Xnnn for anything else
            UInt32 nnn;
            NSScanner *scanner = [NSScanner scannerWithString:[t substringFromIndex:1]];
            [scanner scanHexInt:&nnn];
            switch ([t characterAtIndex:0]) {
                case 'P':
                    // use resorcerer's more consistent n = datalength rather than resedit's n = stringlength
                    _lengthBytes = 1;
                    _maxLength = MIN(nnn-1, UINT8_MAX);
                    _minLength = 0;
                    _terminatingByte = NO;
                    _pad = nnn;
                    break;
                case 'C':
                    _lengthBytes = 0;
                    _maxLength = MIN(nnn-1, UINT8_MAX);
                    _minLength = 0;
                    _terminatingByte = YES;
                    _pad = nnn;
                    break;
            }
        }
	}
	return self;
}


- (id)copyWithZone:(NSZone*)zone
{
	ElementPSTR *element = [super copyWithZone:zone];
	[element setValue:value];
	[element setMaxLength:_maxLength];
	[element setMinLength:_minLength];
	[element setPad:_pad];
	[element setTerminatingByte:_terminatingByte];
	[element setLengthBytes:_lengthBytes];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	// get string length
	UInt32 length = 0;
	if (_lengthBytes > 0) {
		[stream readAmount:_lengthBytes toBuffer:&length];
        length = CFSwapInt32BigToHost(length);
		length >>= (4 - _lengthBytes) << 3;
	}
	if(_terminatingByte)
		length += [stream bytesToNull];
	if(_maxLength && length > _maxLength) length = _maxLength;
	if(length < _minLength) length = _minLength;
	
	// read string
	
    if (length == 0) {
        value = @"";
    } else {
        void *buffer = malloc(length);
        if(_minLength) memset(buffer, 0, _minLength);
        [stream readAmount:length toBuffer:buffer];
        [self setValue:[[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSMacOSRomanStringEncoding freeWhenDone:YES]];
    }
	
	// skip over empty bytes
    if (_terminatingByte) {
        [stream advanceAmount:1 pad:NO];
        length++;
    }
    length += _lengthBytes;
    if (_pad == kPadToOddLength) {
        if (length % 2 == 0) [stream advanceAmount:1 pad:NO];
    } else if (_pad == kPadToEvenLength) {
        if (length % 2 == 1) [stream advanceAmount:1 pad:NO];
    } else if (_pad > 0) {
        if (length < _pad)   [stream advanceAmount:_pad-length pad:NO];
    }
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    if (_pad > 0) return _pad;
	UInt32 length = (UInt32)[value lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding];
	if(_maxLength && length > _maxLength)
		length = _maxLength;
	if(length < _minLength)
		length = _minLength;
	length += _lengthBytes + (_terminatingByte? 1 : 0);
	if(_pad == kPadToOddLength && length % 2 == 0)
		length++;
	if(_pad == kPadToEvenLength && length % 2 == 1)
		length++;
	return length;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	// write string
	UInt32 length = (UInt32)[value length];
	if (_maxLength && length > _maxLength) length = _maxLength;
	if (_lengthBytes > 0) {
        UInt32 writeLength = length << ((4 - _lengthBytes) << 3);
        writeLength = CFSwapInt32HostToBig(writeLength);
		[stream writeAmount:_lengthBytes fromBuffer:&writeLength];
    }
	
	if ([value canBeConvertedToEncoding:NSMacOSRomanStringEncoding])
	{
		const void *buffer = NULL;
		if([value respondsToSelector:@selector(cStringUsingEncoding:)])	// 10.4
			buffer = [value cStringUsingEncoding:NSMacOSRomanStringEncoding];
		else
		{
			NSData *data = [value dataUsingEncoding:NSMacOSRomanStringEncoding];
			buffer = [data bytes];
		}
		if(buffer) [stream writeAmount:length fromBuffer:buffer];
		else [stream advanceAmount:length pad:YES];
	}
	else
	{
		#warning FIXME: This code should display a warning saying that the string in the PSTR is not MacOSRoman
	}
	
	// pad to minimum length with spaces
	if(length < _minLength)
	{
		SInt32 padAmount = _minLength - length;
		while(padAmount > 0)
		{
			UInt32 spaces = '    ';
			[stream writeAmount:(padAmount < 4)? padAmount:4 fromBuffer:&spaces];
			length += (padAmount < 4)? padAmount:4;
			padAmount -= 4;
		}
	}
    if (_terminatingByte) {
		[stream advanceAmount:1 pad:YES];
        length++;
    }
    length += _lengthBytes;
    if (_pad == kPadToOddLength) {
		if (length % 2 == 0) [stream advanceAmount:1 pad:YES];
    } else if (_pad == kPadToEvenLength) {
		if (length % 2 == 1) [stream advanceAmount:1 pad:YES];
    } else if (_pad > 0) {
        if (length < _pad)   [stream advanceAmount:_pad-length pad:YES];
    }
}

@end
