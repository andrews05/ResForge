#import <Cocoa/Cocoa.h>
#import "ElementLSTC.h"
#import "ElementLSTE.h"
#import "ElementOCNT.h"

@implementation ElementLSTC

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	while([stream bytesToGo] > 0)
	{
		Element *element = [stream readOneElement];
		if([[element type] isEqualToString:@"LSTE"])
			break;
		[subElements addObject:element];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[self setCountElement:[stream counter]];
	unsigned int itemsToGo = [countElement value];
	unsigned int itemsToGoAtStart = itemsToGo;
	
	// Read a first item:
	if(itemsToGo > 0)
	{
		[self readDataForElements:stream];
		itemsToGo--;
	}
	
	/* Read additional elements until we have enough items,
		except if we're not the first item in our list. */
	if(self.parentArray)
	{
		while(itemsToGo--)
		{
			// Actually read the item:
			Element *nextItem = [groupElementTemplate copy];	// Make another list item just like this one.
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
		[stream popCounter];
		
		// if it's an empty list delete this LSTC so we only have the empty LSTE.
		if(itemsToGoAtStart == 0)
			[self.parentArray removeObject:self];
	}
}

@end
