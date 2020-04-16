#import "ElementAWRD.h"

@implementation ElementAWRD
@synthesize alignment;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        if ([t isEqualToString:@"AWRD"])
            alignment = 2;
        else if ([t isEqualToString:@"ALNG"])
            alignment = 4;
        else if ([t isEqualToString:@"AL08"])
            alignment = 8;
        else if ([t isEqualToString:@"AL16"])
            alignment = 16;
        else {
            // Annn
            NSScanner *scanner = [NSScanner scannerWithString:[t substringFromIndex:1]];
            [scanner scanHexInt:&alignment];
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ElementAWRD *element = [super copyWithZone:zone];
    [element setAlignment:alignment];
    return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt32 pos = [stream length] - [stream bytesToGo];
    [stream advanceAmount:[self sizeOnDisk:pos] pad:NO];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return -currentSize % alignment;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt32 pos = [stream length] - [stream bytesToGo];
    [stream advanceAmount:[self sizeOnDisk:pos] pad:YES];
}

- (NSString *)stringValue
{
    return @"";
}

- (void)setStringValue:(NSString *)str
{
}

- (NSString *)label
{
    return @"";
}

- (BOOL)editable
{
    return NO;
}

@end
