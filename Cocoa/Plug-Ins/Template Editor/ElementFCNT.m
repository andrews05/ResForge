#import "ElementFCNT.h"

// bug: FCNT doesn't work correctly when adding a new list entry to an outer list containing
// an FCNT list, as its entries are only created when readDataFrom: is called on its LSTB
@implementation ElementFCNT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        // read count from label - hex value denoted by leading '$'
        NSScanner *scanner = [NSScanner scannerWithString:l];
        UInt32 value = 0;
        if ([l characterAtIndex:0] == '$') {
            [scanner setScanLocation:1];
            [scanner scanHexInt:&value];
        } else {
            [scanner scanInt:(SInt32*)&value];
        }
        self.value = value;
    }
    return self;
}

- (void)readDataFrom:(TemplateStream *)stream
{
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 0;
}

- (void)writeDataTo:(TemplateStream *)stream
{
}

@end
