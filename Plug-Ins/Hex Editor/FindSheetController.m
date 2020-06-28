#import "FindSheetController.h"
#import "HexWindowController.h"

@implementation FindSheetController

@synthesize cancelButton;
@synthesize findNextButton;
@synthesize replaceAllButton;
@synthesize findText;
@synthesize replaceText;

@synthesize wrapAroundBox;
@synthesize caseSensitiveBox;
@synthesize searchASCIIOrHexRadios;

@synthesize findBytes;
@synthesize replaceBytes;

/* HIDE AND SHOW SHEET */

+ (instancetype)shared
{
    static FindSheetController *shared = nil;
    if (!shared) {
        shared = [[FindSheetController alloc] initWithWindowNibName:@"FindSheet"];
        [shared window]; // Load window
    }
    return shared;
}

+ (NSData *)hexStringToData:(NSString *)hexString {
    unsigned char *bytes = malloc(hexString.length/2);
    unsigned char *bp = bytes;
    char byte_chars[3] = {0};
    for (int i=0; i < hexString.length; i+=2) {
        byte_chars[0] = (char)[hexString characterAtIndex:i];
        byte_chars[1] = (char)[hexString characterAtIndex:i+1];
        *bp++ = (char)strtol(byte_chars, NULL, 16);
    }
    return [NSData dataWithBytesNoCopy:bytes length:hexString.length/2 freeWhenDone:YES];;
}

+ (NSString *)dataToHexString:(NSData *)data
{
    unichar *hexChars = (unichar *)malloc(sizeof(unichar) * (data.length*2));
    unsigned char *bytes = (unsigned char *)data.bytes;
    for (NSUInteger i=0; i < data.length; i++) {
        unichar c = bytes[i] / 16;
        if (c < 10) {
            c += '0';
        } else {
            c += 'A' - 10;
        }
        hexChars[i*2] = c;

        c = bytes[i] % 16;
        if (c < 10) {
            c += '0';
        } else {
            c += 'A' - 10;
        }
        hexChars[i*2+1] = c;
    }
    return [[NSString alloc] initWithCharactersNoCopy:hexChars length:data.length*2 freeWhenDone:YES];
}
   

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *field = obj.object;
    BOOL asHex = searchASCIIOrHexRadios.selectedRow == 1;
    NSData *data;
    if (asHex) {
        NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
        NSString *hexString = [[field.stringValue.uppercaseString componentsSeparatedByCharactersInSet:hexChars.invertedSet] componentsJoinedByString:@""];
        if (hexString.length % 2 == 1) {
            hexString = [@"0" stringByAppendingString:hexString];
        }
        field.stringValue = hexString;
        data = [FindSheetController hexStringToData:hexString];
    } else {
        data = [field.stringValue dataUsingEncoding:NSMacOSRomanStringEncoding];
    }
    HFByteArray *byteArray = nil;
    if (data.length) {
        HFSharedMemoryByteSlice* slice = [[HFSharedMemoryByteSlice alloc] initWithUnsharedData:data];
        byteArray = [HFBTreeByteArray new];
        [byteArray insertByteSlice:slice inRange:HFRangeMake(0,0)];
    }
    if (field == findText) {
        findBytes = byteArray;
    } else {
        replaceBytes = byteArray;
    }
}

- (void)setFindSelection:(HFController *)controller asHex:(BOOL)asHex
{
    [searchASCIIOrHexRadios setState:NSControlStateValueOn atRow:asHex ? 1 : 0 column:0];
    [searchASCIIOrHexRadios setState:NSControlStateValueOff atRow:asHex ? 0 : 1 column:0];
    HFRange range = [controller.selectedContentsRanges[0] HFRange];
    NSData *data = [controller dataForRange:range];
    if (asHex) {
        findText.stringValue = [FindSheetController dataToHexString:data];
    } else {
        findText.stringValue = [[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding];
    }
    findBytes = [controller byteArrayForSelectedContentsRanges];
}

- (void)showFindSheet:(NSWindow *)window
{
    [self hideFindSheet:self];
    [window beginSheet:self.window completionHandler:nil];
}

- (IBAction)hideFindSheet:(id)sender
{
    [self.window orderOut:sender];
}

- (IBAction)findNext:(id)sender
{
    HexWindowController *controller = [sender window].sheetParent.windowController;
    [self findIn:controller.textView.controller forwards:YES];
}

- (void)findIn:(HFController *)hexController forwards:(BOOL)forwards
{
    if (!findBytes) {
        NSBeep();
        return;
    }
    
    HFRange startRange = HFRangeMake(0, hexController.minimumSelectionLocation);
    HFRange endRange = HFRangeMake(hexController.maximumSelectionLocation, hexController.contentsLength-hexController.maximumSelectionLocation);
    NSUInteger idx = [hexController.byteArray indexOfBytesEqualToBytes:findBytes inRange:forwards ? endRange : startRange searchingForwards:forwards trackingProgress:nil];
    if (idx == ULLONG_MAX && self.wrapAroundBox.state == NSControlStateValueOn) {
        idx = [hexController.byteArray indexOfBytesEqualToBytes:findBytes inRange:forwards ? startRange : endRange searchingForwards:forwards trackingProgress:nil];
    }
    if (idx == ULLONG_MAX) {
        NSBeep();
    } else {
        [self hideFindSheet:self];
        HFRange result = HFRangeMake(idx, findBytes.length);
        [hexController setSelectedContentsRanges:@[[HFRangeWrapper withRange:result]]];
        [hexController maximizeVisibilityOfContentsRange:result];
        [hexController pulseSelection];
    }
}

- (IBAction)replaceAll:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Replacing all \"%@\" with \"%@\"", findText.stringValue, replaceText.stringValue );
}

- (IBAction)replaceFindNext:(id)sender
{
	[self hideFindSheet:self];
	NSLog( @"Replacing \"%@\" with \"%@\" and finding next", findText.stringValue, replaceText.stringValue );
}

@end
