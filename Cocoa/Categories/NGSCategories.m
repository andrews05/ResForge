#import "NGSCategories.h"

@implementation NSArray (NGSKeyValueExtensions)
- (NSInteger)indexOfFirstObjectReturningValue:(id)value forKey:(id)key
{
	return [[self valueForKey:key] indexOfObject:value];
}

- (id)firstObjectReturningValue:(id)value forKey:(id)key
{
	NSUInteger index = [[self valueForKey:key] indexOfObject:value];
	if(index != NSNotFound)
		return self[index];
	else
		return nil;
}

- (NSArray *)objectsReturningValue:(id)value forKey:(id)key
{
	NSMutableArray *array = [NSMutableArray array];
	for (id object in self) {
		if ([[object valueForKey:key] isEqual:value]) {
			[array addObject:object];
		}
	}
	return [NSArray arrayWithArray:array];
}
@end
