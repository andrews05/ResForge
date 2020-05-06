#import "ElementBBIT.h"
#import "ElementBFLG.h"

#define SIZE_ON_DISK (1)

@implementation ElementBBIT

+ (unsigned int)length {
    return 8;
}

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.first = YES;
        if ([[t substringFromIndex:1] isEqualToString:@"BIT"]) {
            self.bits = 1;
        } else {
            // XXnn - bit field or fill bits
            self.bits = [[t substringFromIndex:2] intValue];
            if (self.bits > self.class.length) return nil; // Too big
            self.visible = [t characterAtIndex:1] != 'F'; // Hide fill bits
        }
    }
    return self;
}

- (NSView *)configureView:(NSView *)view
{
    if ([self.type isEqualToString:@"BB08"]) {
        // Display as checkboxes
        NSRect frame = view.frame;
        frame.size.width = 20;
        for (ElementBBIT *element in self.bitList) {
            [view addSubview:[ElementBFLG createCheckboxWithFrame:frame forElement:element]];
            frame.origin.x += 30;
        }
        return view;
    } else if (_bits == 1) {
        [view addSubview:[ElementBFLG createCheckboxWithFrame:view.frame forElement:self]];
        return view;
    } else {
        view = [super configureView:view];
        [view.subviews[0] setPlaceholderString:[NSString stringWithFormat:@"%d bits", _bits]];
        return view;
    }
}

- (void)configure
{
    if (!self.first) return;
    self.bitList = [NSMutableArray new];
    ElementBBIT *element;
    if ([self.type isEqualToString:@"BB08"]) {
        // Special treatment for BB08 (otherwise equivalent to UBYT): display as row of 8 checkboxes
        for (unsigned int pos = 8; pos > 0; pos--) {
            element = [ElementBBIT elementForType:@"BBIT" withLabel:nil];
            element.position = pos - 1;
            [self.bitList addObject:element];
        }
    } else {
        [self.bitList addObject:self];
        unsigned int pos = _position = self.class.length - _bits;
        while (pos > 0) {
            element = (ElementBBIT *)[self.parentList peek:self.bitList.count];
            if (element.class != self.class) {
                NSLog(@"Not enough bits in bit field.");
                break;
            }
            if (element.bits > pos) {
                NSLog(@"'%@' element creates too many bits to complete bit field.", element.type);
                break;
            }
            element.position = pos -= element.bits;
            element.first = NO;
            [self.bitList addObject:element];
        }
    }
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt8 completeValue = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&completeValue];
    for (ElementBBIT* element in self.bitList) {
        element.value = (completeValue >> element.position) & ((1 << element.bits) - 1);
    }
}

- (void)sizeOnDisk:(UInt32 *)size
{
    if (!self.bitList) return;
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt8 completeValue = 0;
    for (ElementBBIT* element in self.bitList) {
        completeValue |= element.value << element.position;
    }
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&completeValue];
}

- (NSFormatter *)formatter
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.hasThousandSeparators = NO;
    formatter.minimum = 0;
    formatter.maximum = @((1 << _bits) - 1);
    formatter.nilSymbol = @"\0";
    return formatter;
}

@end
