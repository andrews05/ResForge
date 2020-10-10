#import "ElementCOLR.h"
#import "Template_Editor-Swift.h"

@implementation ElementCOLR

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        if ([t isEqualToString:@"COLR"]) {
            // 48-bit colour RRRRGGGGBBBB
            self.bytes = 6;
            self.bits = 16;
        } else if ([t isEqualToString:@"WCOL"]) {
            // 15-bit colour
            self.bytes = 2;
            self.bits = 5;
        } else if ([t isEqualToString:@"LCOL"]) {
            // 24-bit colour 00RRGGBB
            self.bytes = 4;
            self.bits = 8;
        }
        self.mask = ((1 << self.bits) - 1);
    }
    return self;
}

- (void)configureView:(NSView *)view
{
    NSRect frame = view.frame;
    frame.size.width = self.width-4;
    NSColorWell *well = [[NSColorWell alloc] initWithFrame:frame];
    well.action = @selector(itemValueUpdated:);
    [well bind:@"value" toObject:self withKeyPath:@"value" options:nil];
    [view addSubview:well];
}

- (NSColor *)value
{
    return [NSColor colorWithRed:(CGFloat)self.r / self.mask
                           green:(CGFloat)self.g / self.mask
                            blue:(CGFloat)self.b / self.mask
                           alpha:1];
}

- (void)setValue:(NSColor *)value
{
    self.r = (UInt64)round(value.redComponent * self.mask);
    self.g = (UInt64)round(value.greenComponent * self.mask);
    self.b = (UInt64)round(value.blueComponent * self.mask);
}

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt64 tmp;
    [stream readAmount:self.bytes toBuffer:&tmp];
    tmp = CFSwapInt64BigToHost(tmp);
    tmp >>= (8 - self.bytes) << 3;
    self.r = (tmp >> self.bits*2) & self.mask;
    self.g = (tmp >> self.bits) & self.mask;
    self.b = tmp & self.mask;
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += self.bytes;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt64 tmp = 0;
    tmp |= self.r << self.bits*2;
    tmp |= self.g << self.bits;
    tmp |= self.b;
    tmp <<= (8 - self.bytes) << 3;
    tmp = CFSwapInt64HostToBig(tmp);
    [stream writeAmount:self.bytes fromBuffer:&tmp];
}

@end
