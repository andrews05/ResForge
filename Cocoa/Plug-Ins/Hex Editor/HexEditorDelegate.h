#import <Cocoa/Cocoa.h>

@interface HexEditorDelegate : NSObject
{
	IBOutlet NSTextView		*ascii;
	IBOutlet NSTextView		*hex;
	IBOutlet NSTextView		*offset;
    IBOutlet NSTextField	*message;
}

- (NSString *)offsetRepresentation:(NSData *)data;
- (NSString *)hexRepresentation:(NSData *)data;
- (NSString *)asciiRepresentation:(NSData *)data;

- (NSRange)byteRangeFromHexRange:(NSRange)hexRange;
- (NSRange)hexRangeFromByteRange:(NSRange)byteRange;
- (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange;
- (NSRange)asciiRangeFromByteRange:(NSRange)byteRange;

- (NSTextView *)hex;
- (NSTextView *)ascii;

@end