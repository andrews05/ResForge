#import "MacRomanFormatter.h"
#import <AppKit/AppKit.h>

@implementation MacRomanFormatter
@synthesize stringLength;
@synthesize valueRequired;
@synthesize exactLengthRequired;

- (NSString *)stringForObjectValue:(id)object {
    return object;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error {
    if (valueRequired && string.length == 0) {
        if (error) {
            *error = @"The value must be not be blank.";
        }
        return NO;
    }
    if (exactLengthRequired && string.length != stringLength) {
        if (error) {
            *error = [NSString stringWithFormat:@"The value must be exactly %d characters.", stringLength];
        }
        return NO;
    }
    if (![string canBeConvertedToEncoding:NSMacOSRomanStringEncoding]) {
        if (error)
            *error = @"The value contains invalid characters for Mac OS Roman encoding.";
        return NO;
    }
    *object = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error
{
    if ([*partialStringPtr length] > stringLength) {
        // If a range is selected then characters in that range will be removed so adjust the insert length accordingly
        NSInteger insertLength = stringLength - origString.length + origSelRange.length;
        
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
