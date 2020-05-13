#import "ElementPNT.h"
#import "ElementRECT.h"

@implementation ElementPNT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.width = 120;
    }
    return self;
}

- (void)configureView:(NSView *)view
{
    [ElementRECT configureFields:@[@"x", @"y"] inView:view forElement:self];
}

- (void)readDataFrom:(ResourceStream *)stream
{
    SInt16 tmp;
    [stream readAmount:2 toBuffer:&tmp];
    self.x = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    self.y = CFSwapInt16BigToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += 4;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(self.x);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(self.y);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
