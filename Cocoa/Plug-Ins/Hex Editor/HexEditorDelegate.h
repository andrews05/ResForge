#import <Cocoa/Cocoa.h>

#import "ResKnifeResourceProtocol.h"

@class HexWindowController, HexTextView, AsciiTextView;

@interface HexEditorDelegate : NSObject

@property (weak) HexWindowController		*controller;
@property (unsafe_unretained) NSTextView	*offset;
@property (unsafe_unretained) HexTextView	*hex;
@property (unsafe_unretained) AsciiTextView	*ascii;
@property (weak) NSTextField				*message;
@property (readonly) NSRange rangeForUserTextChange;
@property BOOL editedLow;

- (void)viewDidScroll:(NSNotification *)notification;
- (NSString *)offsetRepresentation:(NSData *)data;

@end
