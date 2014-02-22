#import "Element.h"

typedef enum StringPadding
{
	kNoPadding = 0,
	kPadToOddLength,
	kPadToEvenLength
} MacStringPadding;

@interface ElementPSTR : Element
{
	NSString *value;
	UInt32 _maxLength;		// for restricted strings
	UInt32 _minLength;
	MacStringPadding _pad; // for odd- and even-padded strings
	BOOL _terminatingByte;	// for C strings
	int _lengthBytes;		// for Pascal strings
	int _alignment;			// pads end to align on multiple of this
}
@property (copy) NSString *stringValue;
@property UInt32 maxLength;
@property UInt32 minLength;
@property MacStringPadding pad;
@property BOOL terminatingByte;
@property int lengthBytes;
@property int alignment;

@end
