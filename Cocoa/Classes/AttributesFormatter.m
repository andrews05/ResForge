#import "AttributesFormatter.h"
#import <Carbon/Carbon.h>

@implementation AttributesFormatter

- (NSString *)stringForObjectValue:(id)obj
{
	BOOL addComma = NO;
	short attributes = [obj shortValue];
	NSMutableString *string = [NSMutableString string];
	if( attributes & resPreload )
	{
		if( addComma )	[string appendString:@", "];
						[string appendString:@"Preload"];
		addComma = YES;
	}
	if( attributes & resProtected )
	{
		if( addComma )	[string appendString:@", "];
						[string appendString:@"Protected"];
		addComma = YES;
	}
	if( attributes & resLocked )
	{
		if( addComma )	[string appendString:@", "];
						[string appendString:@"Locked"];
		addComma = YES;
	}
	if( attributes & resPurgeable )
	{
		if( addComma )	[string appendString:@", "];
						[string appendString:@"Purgeable"];
		addComma = YES;
	}
	if( attributes & resSysHeap )
	{
		if( addComma )	[string appendString:@", "];
						[string appendString:@"SysHeap"];
		addComma = YES;
	}
	return string;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
	NSString *string = [self stringForObjectValue:obj];
	return [[NSAttributedString alloc] initWithString:string attributes:attrs];
}

- (NSString *)editingStringForObjectValue:(id)obj
{
	return nil;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
	return NO;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error
{
	return NO;
}

@end
