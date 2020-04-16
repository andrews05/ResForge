#import "ElementLSTB.h"
#import "ElementLSTC.h"
#import "ElementLSTE.h"
#import "ElementOCNT.h"

// implements LSTB, LSTZ
@implementation ElementLSTB
@dynamic stringValue;
@synthesize countElement;
@synthesize groupElementTemplate;
@synthesize subElements;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if (self) {
		subElements = [[NSMutableArray alloc] init];
		groupElementTemplate = self;
	}
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTB *element = [super copyWithZone:zone];
	if(!element) return nil;
	
	ElementOCNT *counter = nil;
	NSMutableArray *array = [element subElements];			// get empty array created by -initWithType:label:
	[element setGroupElementTemplate:groupElementTemplate];	// override group template (init sets this to self)
	NSUInteger count = [[groupElementTemplate subElements] count];
	for(NSUInteger i = 0; i < count; i++)
	{
		Element *subToClone = [groupElementTemplate subElements][i];
		if([subToClone class] == [ElementLSTB class] ||
		   [subToClone class] == [ElementLSTC class])
		{
			// instead create a terminating 'LSTE' item, using LSTB/C item's label
			ElementLSTE *end = [ElementLSTE elementForType:@"LSTE" withLabel:[subToClone label]];
			[array addObject:end];
			[end setParentArray:array];
			[end setGroupElementTemplate:[(id)subToClone groupElementTemplate]];
			[end setCountElement:counter];
			if([[subToClone type] isEqualToString:@"LSTZ"])
				[end setWritesZeroByte:YES];
		}
		else
		{
			Element *clone = [subToClone copy];
			if([clone class] == [ElementOCNT class])
				counter = (ElementOCNT *)clone;
			[array addObject:clone];
		}
	}
	return element;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	while([stream bytesToGo] > 0)
	{
		Element *element = [stream readOneElement];
		if([[element type] isEqualToString:@"LSTE"])
		{
			if([self.type isEqualToString:@"LSTZ"])
				[(ElementLSTE *)element setWritesZeroByte:YES];
			break;
		}
		[subElements addObject:element];
	}
}

- (void)readDataForElements:(TemplateStream *)stream
{
	int counterValue = 0;
	ElementOCNT *counter = nil;
	for(unsigned i = 0; i < [subElements count]; i++)
	{
		Element *element = subElements[i];
		
		// set up the counter tracking
		if([element class] == [ElementOCNT class])	counter = (ElementOCNT *) element;
		
		// decrement the counter if we have list items
		if([element class] == [ElementLSTC class])	counterValue--;
		
		// if we get to the end of the list and need more items, create them
		if([element class] == [ElementLSTE class] && counterValue > 0)
		{
			NSInteger index = [subElements indexOfObject:element];
			while(counterValue--)
			{
				// create subarray for new data
				ElementLSTB *list = [[(ElementLSTE *)element groupElementTemplate] copy];
				[subElements insertObject:list atIndex:index++];
				[list setParentArray:subElements];
				[list setCountElement:counter];
				
				// read data into it and increment loop
				[list readDataForElements:stream]; i++;
			}
		}
		
		// actually read the data for this item
		[element readDataFrom:stream];
		
		// now that we've read the (possibly counter) data, save it to the local variable
		if(counter) counterValue = [counter value];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
	BOOL isZeroTerminated = [self.type isEqualToString:@"LSTZ"];
	unsigned int bytesToGoAtStart = [stream bytesToGo];
	if(isZeroTerminated)
	{
		char termByte = 0;
		[stream peekAmount:1 toBuffer:&termByte];
		if(termByte)
			[self readDataForElements:stream];
	}
	else [self readDataForElements:stream];
	
	/* Read additional elements until we have enough items,
		except if we're not the first item in our list. */
	if(self.parentArray)
	{
		while([stream bytesToGo] > 0)
		{
			if(isZeroTerminated)
			{
				char termByte = 0;
				[stream peekAmount:1 toBuffer:&termByte];
				if(termByte == 0) break;
			}
			
			// actually read the item
			Element *nextItem = [groupElementTemplate copy];
			[nextItem setParentArray:nil];			// Make sure it doesn't get into this "if" clause.
			[self.parentArray addObject:nextItem];		// Add it below ourselves.
			[nextItem readDataFrom:stream];			// Read it the same way we were.
			[nextItem setParentArray:self.parentArray];	// Set parentArray *after* -readDataFrom: so it doesn't pass the if(parentArray) check above.
		}
		
		// now add a terminating 'LSTE' item, using this item's label
		ElementLSTE *end = [ElementLSTE elementForType:@"LSTE" withLabel:self.label];
		[self.parentArray addObject:end];
		[end setParentArray:self.parentArray];
		[end setGroupElementTemplate:groupElementTemplate];
		[end setCountElement:countElement];
		if(isZeroTerminated)
		{
			[end setWritesZeroByte:YES];
			[end readDataFrom:stream];
		}
		
		// if it's an empty list delete this LSTB so we only have the empty LSTE.
		if(bytesToGoAtStart == 0)
			[self.parentArray removeObject:self];
	}
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	This returns the sizes of all our sub-elements. If you subclass, add to that the size
//	of this element itself.
- (unsigned int)sizeOnDisk
{
	unsigned int size = 0;
	for (Element *element in subElements) {
		size += [element sizeOnDisk];
	}
	return size;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	// Writes out the data of all our sub-elements here:
	for (Element *element in subElements) {
		[element writeDataTo:stream];
	}
}

#pragma mark -

- (NSInteger)subElementCount
{
	return [subElements count];
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	return subElements[n];
}

- (BOOL)createListEntry
{
    if ([countElement.type isEqualToString:@"FCNT"])
        return NO;
    
    ElementLSTB *list = [groupElementTemplate copy];
    [self.parentArray insertObject:list atIndex:[self.parentArray indexOfObject:self]];
    [list setParentArray:self.parentArray];
    [list setCountElement:countElement];
    [countElement addEntry:list after:self];
    return YES;
}

- (BOOL)removeListEntry
{
    if ([countElement.type isEqualToString:@"FCNT"])
        return NO;
    
	[self.parentArray removeObject:self];
    [countElement removeEntry:self];
    return YES;
}

- (NSString *)stringValue { return @""; }
- (void)setStringValue:(NSString *)str {}
- (BOOL)editable { return NO; }
@end
