#import <Foundation/Foundation.h>

@interface AttributesFormatter : NSFormatter
{
}

- (NSString *)stringForObjectValue:(id)obj;
- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs;
- (NSString *)editingStringForObjectValue:(id)obj;
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error;

@end
