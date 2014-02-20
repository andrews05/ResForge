#import "Element.h"

enum StringPadding
{
	kNoPadding = 0,
	kPadToOddLength,
	kPadToEvenLength
};

@interface ElementPSTR : Element
{
	NSString *value;
	UInt32 _maxLength;		// for restricted strings
	UInt32 _minLength;
	enum StringPadding _pad; // for odd- and even-padded strings
	BOOL _terminatingByte;	// for C strings
	int _lengthBytes;		// for Pascal strings
	int _alignment;			// pads end to align on multiple of this
}

- (NSString *)stringValue;
- (void)setStringValue:(NSString *)str;
- (void)setMaxLength:(UInt32)v;
- (void)setMinLength:(UInt32)v;
- (void)setPad:(enum StringPadding)v;
- (void)setTerminatingByte:(BOOL)v;
- (void)setLengthBytes:(int)v;
- (void)setAlignment:(int)v;

@end
