#import "ElementCASE.h"

@implementation ElementCASE

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        self.editable = NO;
        NSArray *components = [l componentsSeparatedByString:@"="];
        self.symbol = [components firstObject];
        self.value = [components lastObject];
    }
    return self;
}

- (NSString *)description
{
    return self.symbol;
}

@end
