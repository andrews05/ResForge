#import "ElementPSTR.h"

// implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, CHAR, TNAM
@implementation ElementPSTR

- (id)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if(!self) return nil;
	value = [@"" retain];
	if     ([t isEqualToString:@"PSTR"] ||
			[t isEqualToString:@"BSTR"])	{ _lengthBytes = 1; _maxLength = UINT8_MAX;  _minLength = 0; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"WSTR"])	{ _lengthBytes = 2; _maxLength = UINT16_MAX; _minLength = 0; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"LSTR"])	{ _lengthBytes = 4; _maxLength = UINT32_MAX; _minLength = 0; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"OSTR"])	{ _lengthBytes = 1; _maxLength = UINT8_MAX-1; _minLength = 0; _terminatingByte = NO; _pad = kPadToOddLength;  _alignment = 0; }
	else if([t isEqualToString:@"ESTR"])	{ _lengthBytes = 1; _maxLength = UINT8_MAX;   _minLength = 0; _terminatingByte = NO; _pad = kPadToEvenLength; _alignment = 0; }
	else if([t isEqualToString:@"CSTR"])	{ _lengthBytes = 0; _maxLength = 0; _minLength = 0; _terminatingByte = YES; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"OCST"])	{ _lengthBytes = 0; _maxLength = 0; _minLength = 0; _terminatingByte = YES; _pad = kPadToOddLength;  _alignment = 0; }
	else if([t isEqualToString:@"ECST"])	{ _lengthBytes = 0; _maxLength = 0; _minLength = 0; _terminatingByte = YES; _pad = kPadToEvenLength; _alignment = 0; }
	else if([t isEqualToString:@"CHAR"])	{ _lengthBytes = 0; _maxLength = 1; _minLength = 1; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"TNAM"])	{ _lengthBytes = 0; _maxLength = 4; _minLength = 4; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	// temp until keyed values are implemented
	else if([t isEqualToString:@"KCHR"])	{ _lengthBytes = 0; _maxLength = 1; _minLength = 1; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	else if([t isEqualToString:@"KTYP"])	{ _lengthBytes = 0; _maxLength = 4; _minLength = 4; _terminatingByte = NO; _pad = kNoPadding; _alignment = 0; }
	return self;
}

- (void)dealloc
{
	[value release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
	ElementPSTR *element = [super copyWithZone:zone];
	[element setStringValue:value];
	[element setMaxLength:_maxLength];
	[element setMinLength:_minLength];
	[element setPad:_pad];
	[element setTerminatingByte:_terminatingByte];
	[element setLengthBytes:_lengthBytes];
	[element setAlignment:_alignment];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	// get string length
	UInt32 length = 0;
	if(_lengthBytes > 0)
	{
		[stream readAmount:_lengthBytes toBuffer:&length];
#if __BIG_ENDIAN__
		length >>= (4 - _lengthBytes) << 3;
#else
		#warning FIXME: This probably doesn't work for WSTR and LSTR on intel machines
#endif
	}
	if(_terminatingByte)
		length += [stream bytesToNull];
	if(_maxLength && length > _maxLength) length = _maxLength;
	if(length < _minLength) length = _minLength;
	
	// read string
	
	if (length == 0)
		return;
	
	void *buffer = malloc(length);
	if(_minLength) memset(buffer, 0, _minLength);
	[stream readAmount:length toBuffer:buffer];
	if([NSString instancesRespondToSelector:@selector(initWithBytesNoCopy:length:encoding:freeWhenDone:)])	// 10.3
		[self setStringValue:[[[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSMacOSRomanStringEncoding freeWhenDone:YES] autorelease]];
	else
	{
		[self setStringValue:[[[NSString alloc] initWithBytes:buffer length:length encoding:NSMacOSRomanStringEncoding] autorelease]];
		free(buffer);
	}
	
	// skip over empty bytes
	if(_terminatingByte) [stream advanceAmount:1 pad:NO];
	if(_pad == kPadToOddLength && (length + _terminatingByte ? 1:0) % 2 == 0)	[stream advanceAmount:1 pad:NO];
	if(_pad == kPadToEvenLength && (length + _terminatingByte ? 1:0) % 2 == 1)	[stream advanceAmount:1 pad:NO];
	// alignment unhandled here
}

- (unsigned int)sizeOnDisk
{
	UInt32 length = [value lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding];
	if(_maxLength && length > _maxLength) length = _maxLength;
	if(length < _minLength) length = _minLength;
	length += _lengthBytes + (_terminatingByte? 1:0);
	if(_pad == kPadToOddLength && length % 2 == 0)	length++;
	if(_pad == kPadToEvenLength && length % 2 == 1)	length++;
	// don't know how to deal with alignment here
	return length;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	// write string
	UInt32 length = [value length], writeLength;
	if(_maxLength && length > _maxLength) length = _maxLength;
#if __BIG_ENDIAN__
	writeLength = length << ((4 - _lengthBytes) << 3);
#else
	#warning FIXME: This probably doesn't work for WSTR and LSTR on intel machines
#endif
	if(_lengthBytes)
		[stream writeAmount:_lengthBytes fromBuffer:&writeLength];
	
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
	if(_terminatingByte) [stream advanceAmount:1 pad:YES];
	if(_pad == kPadToOddLength && (length + _lengthBytes + (_terminatingByte? 1:0)) % 2 == 0)	[stream advanceAmount:1 pad:YES];
	if(_pad == kPadToEvenLength && (length + _lengthBytes + (_terminatingByte? 1:0)) % 2 == 1)	[stream advanceAmount:1 pad:YES];
}

- (NSString *)stringValue
{
	return value;
}

- (void)setStringValue:(NSString *)str
{
	id old = value;
	value = [str copy];
	[old release];
}

- (void)setMaxLength:(UInt32)v { _maxLength = v; }
- (void)setMinLength:(UInt32)v { _minLength = v; }
- (void)setPad:(enum StringPadding)v { _pad = v; }
- (void)setTerminatingByte:(BOOL)v { _terminatingByte = v; }
- (void)setLengthBytes:(int)v { _lengthBytes = v; }
- (void)setAlignment:(int)v { _alignment = v; }

@end
