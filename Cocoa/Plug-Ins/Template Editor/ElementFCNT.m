#import "ElementFCNT.h"

@implementation ElementFCNT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        // Read count from label - hex value denoted by leading '$'
        NSScanner *scanner = [NSScanner scannerWithString:l];
        UInt32 value = 0;
        if ([l characterAtIndex:0] == '$') {
            [scanner setScanLocation:1];
            [scanner scanHexInt:&value];
        } else {
            [scanner scanInt:(SInt32*)&value];
        }
        self.value = value;
        // Remove count from label
        self.displayLabel = [[l substringFromIndex:scanner.scanLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        // Hide if no remaining label
        if (!self.displayLabel.length) self.visible = NO;
    }
    return self;
}

- (NSString *)label
{
    return self.displayLabel;
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
