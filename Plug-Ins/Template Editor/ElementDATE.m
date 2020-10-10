#import "ElementDATE.h"
#import "Template_Editor-Swift.h"

@implementation ElementDATE

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.width = 240;
        // Set the default value to the current time
        UInt32 seconds;
        UCConvertCFAbsoluteTimeToSeconds(CFAbsoluteTimeGetCurrent(), &seconds);
        self.value = seconds;
    }
    return self;
}

- (void)configureView:(NSView *)view
{
    NSRect frame = view.frame;
    frame.size.width = self.width-4;
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:frame];
    picker.font = [NSFont systemFontOfSize:12];
    picker.drawsBackground = YES;
    picker.action = @selector(itemValueUpdated:);
    [picker bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self}];
    [view addSubview:picker];
}

- (id)transformedValue:(id)value
{
    CFAbsoluteTime cfTime;
    OSStatus error = UCConvertSecondsToCFAbsoluteTime([value intValue], &cfTime);
    if (error) return nil;
    return [NSDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime];
}

- (id)reverseTransformedValue:(id)value
{
    UInt32 seconds;
    UCConvertCFAbsoluteTimeToSeconds((CFAbsoluteTime)[value timeIntervalSinceReferenceDate], &seconds);
    return @(seconds);
}

@end
