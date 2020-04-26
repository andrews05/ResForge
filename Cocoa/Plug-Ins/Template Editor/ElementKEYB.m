#import "ElementKEYB.h"

@implementation ElementKEYB

- (id)copyWithZone:(NSZone *)zone
{
    ElementKEYB *element = [super copyWithZone:zone];
    if (!element) return nil;
    element.subElements = [self.subElements copyWithZone:zone];
    return element;
}

- (void)readSubElements
{
    self.subElements = [self.parentList subListUntil:@"KEYE"];
}

- (void)readDataFrom:(ResourceStream *)stream
{
	if ([self matchesKey]) {
        [self.subElements readDataFrom:stream];
	}
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	This returns the sizes of all our sub-elements. If you subclass, add to that the size
//	of this element itself.
- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	if (![self matchesKey])
		return 0;
    return [self.subElements sizeOnDisk:currentSize];
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if ([self matchesKey]) {
		// writes out the data of all our sub-elements here:
		[self.subElements writeDataTo:stream];
	}
}

- (NSInteger)subElementCount
{
	return self.subElements.count;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	return [self.subElements elementAtIndex:n];
}

- (BOOL)matchesKey
{
    NSString *value = [[self.keyElement formatter] stringForObjectValue:[self.keyElement valueForKey:@"value"]];
    return [self.label isEqualToString:value];
}

@end
