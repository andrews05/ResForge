#import "ElementPSTR.h"
#import "TemplateWindowController.h"

// implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, Pnnn, Cnnn
@implementation ElementPSTR

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	if (self = [super initForType:t withLabel:l]) {
		if ([t isEqualToString:@"PSTR"] || [t isEqualToString:@"BSTR"])	{
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if([t isEqualToString:@"WSTR"]) {
			_lengthBytes = 2;
			_maxLength = UINT16_MAX;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"LSTR"]) {
			_lengthBytes = 4;
			_maxLength = UINT32_MAX;
			_terminatingByte = NO;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"OSTR"]) {
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_terminatingByte = NO;
			_pad = kPadToOddLength;
		} else if ([t isEqualToString:@"ESTR"]) {
			_lengthBytes = 1;
			_maxLength = UINT8_MAX;
			_terminatingByte = NO;
			_pad = kPadToEvenLength;
		} else if ([t isEqualToString:@"CSTR"]) {
			_lengthBytes = 0;
			_maxLength = UINT32_MAX;
			_terminatingByte = YES;
			_pad = kNoPadding;
		} else if ([t isEqualToString:@"OCST"]) {
			_lengthBytes = 0;
			_maxLength = UINT32_MAX;
			_terminatingByte = YES;
			_pad = kPadToOddLength;
		} else if ([t isEqualToString:@"ECST"]) {
			_lengthBytes = 0;
			_maxLength = UINT32_MAX;
			_terminatingByte = YES;
			_pad = kPadToEvenLength;
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
                    _terminatingByte = NO;
                    _pad = nnn;
                    break;
                case 'C':
                    _lengthBytes = 0;
                    _maxLength = MIN(nnn-1, UINT8_MAX);
                    _terminatingByte = YES;
                    _pad = nnn;
                    break;
            }
        }
	}
	return self;
}

- (void)configure
{
    [super configure];
    self.width = (!self.cases && _maxLength > 32) ? 0 : 240;
}

- (void)configureView:(NSView *)view
{
    [super configureView:view];
    NSTextField *textField = view.subviews[0];
    if (_maxLength < UINT32_MAX)
        textField.placeholderString = [self.type stringByAppendingFormat:@" (%u characters)", _maxLength];
    if (self.width == 0) {
        textField.lineBreakMode = NSLineBreakByWordWrapping;
        textField.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self performSelector:@selector(autoRowHeight:) withObject:textField afterDelay:0];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    if (self.width == 0)
        [self autoRowHeight:obj.object];
}

// Automatically adjust the row height to fit the text
// TODO: Find a better way to do this?
- (void)autoRowHeight:(NSTextField *)field
{
    NSOutlineView *outlineView = self.parentList.controller.dataList;
    NSUInteger index = [outlineView rowForView:field];
    Element *element = [outlineView itemAtRow:index];
    NSRect bounds = NSMakeRect(0, 0, field.bounds.size.width-4, CGFLOAT_MAX);
    double height = [field.cell cellSizeForBounds:bounds].height + 1;
    if (height == element.rowHeight)
        return;
    element.rowHeight = height;
    // Notify the outline view
    [outlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:index]];
}

- (void)readDataFrom:(ResourceStream *)stream
{
	// get string length
	UInt32 length = 0;
	if (_lengthBytes > 0) {
		[stream readAmount:_lengthBytes toBuffer:&length];
        length = CFSwapInt32BigToHost(length);
		length >>= (4 - _lengthBytes) << 3;
	}
	if (_terminatingByte)
		length = [stream bytesToNull];
	if (length > _maxLength) length = _maxLength;
    if (length > [stream bytesToGo]) length = [stream bytesToGo];
	
	// read string
    if (length == 0) {
        self.value = @"";
    } else {
        void *buffer = malloc(length);
        [stream readAmount:length toBuffer:buffer];
        self.value = [[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSMacOSRomanStringEncoding freeWhenDone:YES];
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

- (void)sizeOnDisk:(UInt32 *)size
{
    if (_pad > 0) {
        *size += _pad;
        return;
    }
	UInt32 length = (UInt32)[self.value lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding];
	if (length > _maxLength) length = _maxLength;
	length += _lengthBytes + (_terminatingByte? 1 : 0);
	if (_pad == kPadToOddLength && length % 2 == 0)
		length++;
	if (_pad == kPadToEvenLength && length % 2 == 1)
		length++;
	*size += length;
}

- (void)writeDataTo:(ResourceStream *)stream
{
	// write string
	UInt32 length = (UInt32)[self.value length];
	if (length > _maxLength) length = _maxLength;
	if (_lengthBytes > 0) {
        UInt32 writeLength = length << ((4 - _lengthBytes) << 3);
        writeLength = CFSwapInt32HostToBig(writeLength);
		[stream writeAmount:_lengthBytes fromBuffer:&writeLength];
    }
	
    const void *buffer = [self.value cStringUsingEncoding:NSMacOSRomanStringEncoding];
    if (buffer)
        [stream writeAmount:length fromBuffer:buffer];
    else
        [stream advanceAmount:length pad:YES];
	
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

- (NSFormatter *)formatter
{
    MacRomanFormatter *formatter = [[MacRomanFormatter alloc] init];
    formatter.stringLength = _maxLength;
    return formatter;
}

@end
