#import <Cocoa/Cocoa.h>

#import "ResKnifeResourceProtocol.h"

@class HexWindowController;

@interface HexEditorDelegate : NSObject
{
    IBOutlet HexWindowController *controller;
	IBOutlet NSTextView		*ascii;
	IBOutlet NSTextView		*hex;
	IBOutlet NSTextView		*offset;
    IBOutlet NSTextField	*message;
	
	BOOL editedLow;
}

- (NSString *)offsetRepresentation:(NSData *)data;
- (NSString *)hexRepresentation:(NSData *)data;
- (NSString *)asciiRepresentation:(NSData *)data;
- (NSString *)hexToAscii:(NSData *)data;

- (NSRange)byteRangeFromHexRange:(NSRange)hexRange;
- (NSRange)hexRangeFromByteRange:(NSRange)byteRange;
- (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange;
- (NSRange)asciiRangeFromByteRange:(NSRange)byteRange;

- (NSTextView *)hex;
- (NSTextView *)ascii;

- (BOOL)editedLow;
- (void)setEditedLow:(BOOL)flag;

@end