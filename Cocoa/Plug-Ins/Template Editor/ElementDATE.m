#import "ElementDATE.h"
#import "TemplateWindowController.h"

@implementation ElementDATE

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    NSRect frame = NSMakeRect(0, 0, 300, self.rowHeight);
    NSView *view = [[NSView alloc] initWithFrame:frame];
    frame.size.width = 240-4;
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:frame];
    picker.action = @selector(itemValueUpdated:);
    [picker bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self}];
    picker.drawsBackground = YES;
    [view addSubview:picker];
    return view;
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
