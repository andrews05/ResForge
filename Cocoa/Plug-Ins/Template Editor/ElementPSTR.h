#import "Element.h"

typedef enum StringPadding
{
	kNoPadding = 0,
	kPadToOddLength,
	kPadToEvenLength
} MacStringPadding;

@interface ElementPSTR : Element
@property (copy) NSString *stringValue;
@property UInt32 maxLength;		// for restricted strings
@property UInt32 minLength;
@property MacStringPadding pad;	// for odd- and even-padded strings
@property BOOL terminatingByte;	// for C strings
@property int lengthBytes;		// for Pascal strings
@property int alignment;		// pads end to align on multiple of this

@end
