#import "ElementCASE.h"

@implementation ElementCASE

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        NSArray *components = [l componentsSeparatedByString:@"="];
        self.displayLabel = [components firstObject];
        self.value = [components lastObject];
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
