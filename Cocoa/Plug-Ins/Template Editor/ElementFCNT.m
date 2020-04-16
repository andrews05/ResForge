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
        self.entries = [NSMutableArray arrayWithCapacity:value];
        // remove count and leading spaces from label
        self.label = [[scanner string] substringFromIndex: [scanner scanLocation]];
        self.label = [self.label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ElementOCNT *element = [super copyWithZone:zone];
    if(!element) return nil;
    
    // always reset counter on copy
    element.value = self.value;
    return element;
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
