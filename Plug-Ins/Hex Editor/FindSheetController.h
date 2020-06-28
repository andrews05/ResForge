#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

@interface FindSheetController : NSWindowController <NSTextFieldDelegate>
@property (weak) IBOutlet NSButton	*cancelButton;
@property (weak) IBOutlet NSButton	*findNextButton;
@property (weak) IBOutlet NSButton	*replaceAllButton;
@property (weak) IBOutlet NSTextField	*findText;
@property (weak) IBOutlet NSTextField	*replaceText;

@property (weak) IBOutlet NSButton	*wrapAroundBox;
@property (weak) IBOutlet NSButton	*caseSensitiveBox;
@property (weak) IBOutlet NSMatrix	*searchASCIIOrHexRadios;

@property HFByteArray *findBytes;
@property HFByteArray *replaceBytes;

+ (instancetype)shared;

- (IBAction)hideFindSheet:(id)sender;

- (IBAction)findNext:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)replaceFindNext:(id)sender;

- (void)showFindSheet:(NSWindow *)window;
- (void)findIn:(HFController *)hexController forwards:(BOOL)forwards;
- (void)setFindSelection:(HFController *)hexController asHex:(BOOL)asHex;

@end
