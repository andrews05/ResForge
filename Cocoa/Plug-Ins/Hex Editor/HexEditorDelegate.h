#import <Cocoa/Cocoa.h>

@interface HexEditorDelegate : NSObject
{
	IBOutlet NSTextView		*ascii;
	IBOutlet NSTextView		*hex;
	IBOutlet NSTextView		*offset;
}

- (NSString *)offsetRepresentation:(NSData *)data;
- (NSString *)hexRepresentation:(NSData *)data;
- (NSString *)asciiRepresentation:(NSData *)data;

- (NSTextView *)hex;
- (NSTextView *)ascii;

@end