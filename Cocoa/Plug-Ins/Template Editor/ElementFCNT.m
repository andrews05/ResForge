#import "ElementFCNT.h"

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
