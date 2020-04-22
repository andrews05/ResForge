#import "ElementKEYB.h"

@implementation ElementKEYB
@synthesize subElements;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if(!self) return nil;
	subElements = [[NSMutableArray alloc] init];
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
    ElementKEYB *element = [super copyWithZone:zone];
    if(!element) return nil;
    element.subElements = [subElements copyWithZone:zone];
    return element;
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
	if([self labelMatches:[stream key]])
	{
		for(unsigned i = 0; i < [subElements count]; i++)
			[subElements[i] readDataFrom:stream];
	}
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	This returns the sizes of all our sub-elements. If you subclass, add to that the size
//	of this element itself.
- (UInt32)sizeOnDisk:(UInt32)currentSize
{
//	if(![self labelMatches:[stream key]])
//		return 0;
	
	UInt32 size = 0;
	for (Element *element in subElements)
        size += [element sizeOnDisk:(currentSize + size)];
	return size;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    if([self labelMatches:[stream key]])
	{
		// writes out the data of all our sub-elements here:
		for (Element *element in subElements)
			[element writeDataTo:stream];
	}
}

- (NSInteger)subElementCount
{
	return [subElements count];
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	return subElements[n];
}

- (BOOL)labelMatches:(Element *)element
{
    NSString *value = [[element formatter] stringForObjectValue:[element valueForKey:@"value"]];
    return [[self label] isEqualToString:value];
}

@end

#pragma mark -

@implementation ElementKEYE
- (void)readDataFrom:(TemplateStream *)stream {}
- (void)writeDataTo:(TemplateStream *)stream {}
- (BOOL)editable { return NO; }
@end
