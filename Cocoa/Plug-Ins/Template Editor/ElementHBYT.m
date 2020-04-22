#import "ElementHBYT.h"

@implementation ElementHBYT

+ (NSFormatter *)sharedFormatter
{
    static HexFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[HexFormatter alloc] init];
        formatter.byteCount = 1;
    }
    return formatter;
}

@end


@implementation HexFormatter
@synthesize byteCount;
@synthesize invalidChars;

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    invalidChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
    return self;
}

- (NSString *)stringForObjectValue:(id)object {
    // Prefix with $ when not editing
    if ([object isKindOfClass:[NSNumber class]]) {
        NSString *format = [NSString stringWithFormat:@"$%%0%uX", byteCount*2];
        return [NSString stringWithFormat:format, [object intValue]];
    }
    return nil;
}

- (NSString *)editingStringForObjectValue:(id)object {
    if ([object isKindOfClass:[NSNumber class]]) {
        NSString *format = [NSString stringWithFormat:@"%%0%uX", byteCount*2];
        return [NSString stringWithFormat:format, [object intValue]];
    }
    return nil;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error {
    if (string.length < byteCount*2)
        string = [string stringByPaddingToLength:byteCount*2 withString:@"0" startingAtIndex:0];
    UInt64 value = 0;
    NSScanner* scanner = [NSScanner scannerWithString:string];
    [scanner scanHexLongLong:&value];
    *object = [NSNumber numberWithLongLong:value];
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error
{
    // Reject input with non-hex chars
    NSArray *components = [*partialStringPtr componentsSeparatedByCharactersInSet:invalidChars];
    if (components.count > 1) {
        *partialStringPtr = [origString copy];
        *proposedSelRangePtr = origSelRange;
        NSBeep();
        return NO;
    }
    if ([*partialStringPtr length] > byteCount*2) {
        // If a range is selected then characters in that range will be removed so adjust the insert length accordingly
        NSInteger insertLength = byteCount*2 - origString.length + origSelRange.length;
        
        // Assemble the string
        NSString *prefix = [origString substringToIndex:origSelRange.location];
        NSString *insert = [*partialStringPtr substringWithRange:NSMakeRange(origSelRange.location, insertLength)];
        NSString *suffix = [origString substringFromIndex:origSelRange.location + origSelRange.length];
        *partialStringPtr = [[prefix stringByAppendingString:insert] stringByAppendingString:suffix];
        
        // Fix-up the proposed selection range
        proposedSelRangePtr->location = origSelRange.location + insertLength;
        proposedSelRangePtr->length = 0;
        NSBeep();
        return NO;
    }
    
    return YES;
}

@end
