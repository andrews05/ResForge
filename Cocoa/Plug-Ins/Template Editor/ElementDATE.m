#import "ElementDATE.h"
#import "TemplateWindowController.h"

@implementation ElementDATE

- (void)configureView:(NSView *)view
{
    NSRect frame = view.frame;
    frame.size.width = 240-4;
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:frame];
    picker.action = @selector(itemValueUpdated:);
    [picker bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self}];
    picker.drawsBackground = YES;
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
