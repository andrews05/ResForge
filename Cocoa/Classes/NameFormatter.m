#import "NameFormatter.h"
#import "NSOutlineView-SelectedItems.h"
#import "Resource.h"

@implementation NameFormatter

- (NSString *)stringForObjectValue:(id)obj
{
	if( ![obj isKindOfClass:[NSString class]] ) return nil;
	if( [obj isEqualToString:@""] )
	{
		// unfortunetly this is wrong, the resource I'm being asked about is NOT the selected one!
		if( [[(Resource *)[outlineView selectedItem] type] isEqualToString:@"icns"] )
			return NSLocalizedString( @"Custom Icon", nil );
		else return NSLocalizedString( @"Untitled Resource", nil );
	}
	else return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
	NSString *string = [self stringForObjectValue:obj];
	if( [obj isEqualToString:@""] )
		return [[NSAttributedString alloc] initWithString:string attributes:[NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName]];
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
