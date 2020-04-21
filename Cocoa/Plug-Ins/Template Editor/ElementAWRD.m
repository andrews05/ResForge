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
    }
    return self;
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

- (NSString *)label
{
    return @"";
}

@end
