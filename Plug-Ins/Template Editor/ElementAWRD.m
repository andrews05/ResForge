#import "ElementAWRD.h"

@implementation ElementAWRD

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        if ([t isEqualToString:@"AWRD"])
            _alignment = 2;
        else if ([t isEqualToString:@"ALNG"])
            _alignment = 4;
        else if ([t isEqualToString:@"AL08"])
            _alignment = 8;
        else if ([t isEqualToString:@"AL16"])
            _alignment = 16;
    }
    return self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt32 pos = [stream length] - [stream bytesToGo];
    [stream advanceAmount:(-pos % _alignment) pad:NO];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += -*size % _alignment;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt32 pos = [stream length] - [stream bytesToGo];
    [stream advanceAmount:(-pos % _alignment) pad:YES];
}

- (NSString *)label
{
    return @"";
}

@end
