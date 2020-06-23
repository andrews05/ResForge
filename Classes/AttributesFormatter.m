#import "AttributesFormatter.h"
@import CoreServices.CarbonCore.Resources;

@implementation AttributesFormatter

- (NSString *)stringForObjectValue:(id)obj
{
	if( [obj isKindOfClass: [NSString class]] )
		return obj;
	
	BOOL addComma = NO;
	ResAttributes attributes = (short)[obj intValue];
	NSMutableString *string = [[NSMutableString alloc] init];
	
	// there's probably a smarter, bitwise, way to do this
	short attributeCount = 0;
	if( attributes & resPreload )	attributeCount++;
	if( attributes & resProtected )	attributeCount++;
	if( attributes & resLocked )	attributeCount++;
	if( attributes & resPurgeable )	attributeCount++;
	if( attributes & resSysHeap )	attributeCount++;
	
	// create string
	if( attributes & resPreload )
	{
		if( addComma )				[string appendString:@", "];
		if( attributeCount > 2 )	[string appendString:@"Pre"];
		else						[string appendString:@"Preload"];
		addComma = YES;
	}
	if( attributes & resProtected )
	{
		if( addComma )				[string appendString:@", "];
		if( attributeCount > 2 )	[string appendString:@"Pro"];
		else						[string appendString:@"Protected"];
		addComma = YES;
	}
	if( attributes & resLocked )
	{
		if( addComma )				[string appendString:@", "];
		if( attributeCount > 2 )	[string appendString:@"L"];
		else						[string appendString:@"Locked"];
		addComma = YES;
	}
	if( attributes & resPurgeable )
	{
		if( addComma )				[string appendString:@", "];
		if( attributeCount > 2 )	[string appendString:@"Pur"];
		else						[string appendString:@"Purgeable"];
		addComma = YES;
	}
	if( attributes & resSysHeap )
	{
		if( addComma )				[string appendString:@", "];
		if( attributeCount > 2 )	[string appendString:@"Sys"];
		else						[string appendString:@"SysHeap"];
		/* addComma = YES; */
	}
	return [NSString stringWithString:string];
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
	NSString *string = [obj isKindOfClass: [NSString class]] ? obj : [self stringForObjectValue: obj];
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
