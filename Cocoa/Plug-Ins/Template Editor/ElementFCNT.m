#import "ElementFCNT.h"

@implementation ElementFCNT

- (void)readSubElements
{
    [super readSubElements];
    // Read count from label - hex value denoted by leading '$'
    NSScanner *scanner = [NSScanner scannerWithString:self.label];
    UInt32 value = 0;
    if ([self.label characterAtIndex:0] == '$') {
        [scanner setScanLocation:1];
        [scanner scanHexInt:&value];
    } else {
        [scanner scanInt:(SInt32*)&value];
    }
    // Remove count from label
    self.label = [[self.label substringFromIndex:scanner.scanLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.value = value;
}

- (void)readDataFrom:(ResourceStream *)stream
{
}

- (void)sizeOnDisk:(UInt32 *)size
{
}

- (void)writeDataTo:(ResourceStream *)stream
{
}

@end
