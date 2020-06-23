#import "ElementCASE.h"

@implementation ElementCASE

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        self.value = [[l componentsSeparatedByString:@"="] lastObject];
    }
    return self;
}

- (NSString *)description
{
    return self.displayLabel;
}

- (void)configure
{
    NSLog(@"CASE element not associated to an element that supports cases.");
}

@end
