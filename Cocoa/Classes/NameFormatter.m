#import "NameFormatter.h"
#import <AppKit/NSColor.h>

@implementation NameFormatter

- (NSString *)stringForObjectValue:(id)obj
{
	if( ![obj isKindOfClass:[NSString class]] ) return nil;
	if( [obj isEqualToString:@""] )
	{
		if( NO ) return NSLocalizedString( @"Custom Icon", nil );
		else return NSLocalizedString( @"Untitled Resource", nil );
	}
	else return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
	NSString *string = [self stringForObjectValue:obj];
	if( [obj isEqualToString:@""] )
		return [[NSAttributedString alloc] initWithString:string attributes:[NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:@"NSColor"]];
	else return [[NSAttributedString alloc] initWithString:string attributes:attrs];
}

- (NSString *)editingStringForObjectValue:(id)obj
{
	return obj;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
	*obj = string;
	return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error
{
	return YES;
}

@end
