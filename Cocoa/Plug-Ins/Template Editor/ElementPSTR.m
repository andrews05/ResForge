#import "ElementPSTR.h"
#import "TemplateWindowController.h"

// implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, Pnnn, Cnnn
@implementation ElementPSTR
@synthesize value;
@synthesize lengthBytes = _lengthBytes;
@synthesize maxLength = _maxLength;
@synthesize pad = _pad;
@synthesize terminatingByte = _terminatingByte;

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

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSTableCellView *view = (NSTableCellView *)[super outlineView:outlineView viewForTableColumn:tableColumn];
    if (_maxLength < UINT32_MAX)
        view.textField.placeholderString = [self.type stringByAppendingFormat:@" (%u characters)", _maxLength];
    [self performSelector:@selector(autoRowHeight:) withObject:view.textField afterDelay:0];
    return view;
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *field = (NSTextField *)[[obj.userInfo objectForKey:@"NSFieldEditor"] delegate];
    [self autoRowHeight:field];
}

// Automatically adjust the row height to fit the text
// TODO: Find a better way to do this?
- (void)autoRowHeight:(NSTextField *)field
{
    NSRect bounds = field.bounds;
    bounds.size.height = CGFLOAT_MAX;
    double height = [field.cell cellSizeForBounds:bounds].height;
    if (height == self.rowHeight)
        return;
    self.rowHeight = height;
    // Find the outline view to notify it
    NSView *view = field;
    while ((view = view.superview)) {
        if ([view isKindOfClass:[NSOutlineView class]]) {
            NSOutlineView *outlineView = (NSOutlineView *)view;
            NSUInteger index = [outlineView rowForItem:self];
            [outlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:index]];
            break;
        }
    }
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
	if (_terminatingByte)
		length = [stream bytesToNull];
	if (length > _maxLength) length = _maxLength;
    if (length > [stream bytesToGo]) length = [stream bytesToGo];
	
	// read string
    if (length == 0) {
        value = @"";
    } else {
        void *buffer = malloc(length);
        [stream readAmount:length toBuffer:buffer];
        value = [[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSMacOSRomanStringEncoding freeWhenDone:YES];
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
	if (length > _maxLength) length = _maxLength;
	length += _lengthBytes + (_terminatingByte? 1 : 0);
	if (_pad == kPadToOddLength && length % 2 == 0)
		length++;
	if (_pad == kPadToEvenLength && length % 2 == 1)
		length++;
	return length;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	// write string
	UInt32 length = (UInt32)[value length];
	if (length > _maxLength) length = _maxLength;
	if (_lengthBytes > 0) {
        UInt32 writeLength = length << ((4 - _lengthBytes) << 3);
        writeLength = CFSwapInt32HostToBig(writeLength);
		[stream writeAmount:_lengthBytes fromBuffer:&writeLength];
    }
	
    const void *buffer = [value cStringUsingEncoding:NSMacOSRomanStringEncoding];
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


@implementation MacRomanFormatter
@synthesize stringLength;
@synthesize exactLengthRequired;

- (NSString *)stringForObjectValue:(id)object {
    return object;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error {
    if (exactLengthRequired && [string length] != stringLength) {
        if (error) {
            *error = [NSString stringWithFormat:@"The value must be exactly %d characters.", stringLength];
        }
        return NO;
    }
    if (![string canBeConvertedToEncoding:NSMacOSRomanStringEncoding]) {
        if (error)
            *error = @"The value contains invalid characters for Mac OS Roman encoding.";
        return NO;
    }
    *object = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error
{
    if ([*partialStringPtr length] > stringLength) {
        // If a range is selected then characters in that range will be removed so adjust the insert length accordingly
        NSInteger insertLength = stringLength - origString.length + origSelRange.length;

        // Assemble the string
        NSString *prefix = [origString substringToIndex:origSelRange.location];
        NSString *insert = [*partialStringPtr substringWithRange:NSMakeRange(origSelRange.location, insertLength)];
        NSString *suffix = [origString substringFromIndex:origSelRange.location + origSelRange.length];
        *partialStringPtr = [[prefix stringByAppendingString:insert] stringByAppendingString:suffix];

        // Fix-up the proposed selection range
        proposedSelRangePtr->location = origSelRange.location + insertLength;
        proposedSelRangePtr->length = 0;
        return NO;
    }

    return YES;
}

@end
