#import "ElementKEYB.h"

@implementation ElementKEYB

- (id)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if(!self) return nil;
	subElements = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	[subElements release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	return nil;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	while([stream bytesToGo] > 0)
	{
		Element *element = [stream readOneElement];
		if([[element type] isEqualToString:@"KEYE"])
			break;
		[subElements addObject:element];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
	if([[self label] isEqualToString: [[stream key] stringValue]])
	{
		for(unsigned i = 0; i < [subElements count]; i++)
			[[subElements objectAtIndex:i] readDataFrom:stream];
	}
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	This returns the sizes of all our sub-elements. If you subclass, add to that the size
//	of this element itself.
- (unsigned int)sizeOnDisk
{
//	if(![[self label] isEqualToString: [[stream key] stringValue]])
//		return 0;
	
	unsigned int size = 0;
	for (Element *element in subElements)
		size += [element sizeOnDisk];
	return size;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	if([[self label] isEqualToString: [[stream key] stringValue]])
	{
		// writes out the data of all our sub-elements here:
		for (Element *element in subElements)
			[element writeDataTo:stream];
	}
}

- (void)setSubElements:(NSMutableArray *)a
{
	id old = subElements;
	subElements = [a retain];
	[old release];
}

- (NSMutableArray *)subElements
{
	return subElements;
}

- (int)subElementCount
{
	return [subElements count];
}

- (Element *)subElementAtIndex:(int)n
{
	return [subElements objectAtIndex:n];
}

- (NSString *)stringValue { return @""; }
- (void)setStringValue:(NSString *)str {}
- (BOOL)editable { return NO; }
@end

#pragma mark -

@implementation ElementKEYE
- (void)readDataFrom:(TemplateStream *)stream {}
- (void)writeDataTo:(TemplateStream *)stream {}
- (NSString *)stringValue { return @""; }
- (void)setStringValue:(NSString *)str {}
- (BOOL)editable { return NO; }
@end
