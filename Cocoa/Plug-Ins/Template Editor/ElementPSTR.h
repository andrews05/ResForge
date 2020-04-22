#import "Element.h"

typedef enum StringPadding
{
	kNoPadding = 0,
	kPadToOddLength = -1,
	kPadToEvenLength = -2
} MacStringPadding;

@interface ElementPSTR : Element
@property (copy) NSString *value;
@property UInt32 maxLength;		// for restricted strings
@property MacStringPadding pad;	// for odd- and even-padded strings
@property BOOL terminatingByte;	// for C strings
@property int lengthBytes;		// for Pascal strings

@end


@interface MacRomanFormatter : NSFormatter
@property UInt32 stringLength;
@property BOOL exactLengthRequired;

@end
