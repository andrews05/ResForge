//
//  NuTemplateLSTBElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateLSTBElement.h"
#import "NuTemplateLSTEElement.h"


@implementation NuTemplateLSTBElement

-(void)		readSubElementsFrom: (NuTemplateStream*)stream
{
	while( [stream bytesToGo] > 0 )
	{
		NuTemplateElement*	obj = [stream readOneElement];
		
		if( [[obj type] isEqualToString: @"LSTE"] )
			break;
		[subElements addObject: obj];
	}
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	NSEnumerator		*enny = [subElements objectEnumerator];
	NuTemplateElement	*el, *nextItem;
	unsigned int		bytesToGoAtStart = [stream bytesToGo];
	
	/* Fill this first list element with data:
		If there is no more data in the stream, the items will
		fill themselves with default values. */
	while( el = [enny nextObject] )
	{
		[el readDataFrom: stream];
	}
	
	/* Read additional elements until we have enough items,
		except if we're not the first item in our list. */
	if( containing != nil )
	{
		while( [stream bytesToGo] > 0 )
		{
			nextItem = [self copy];				// Make another list item just like this one.
			[containing addObject: nextItem];	// Add it below ourselves.
			[nextItem readDataFrom:stream];		// Read it the same way we were.
			[nextItem setContaining: containing];	// Set "containing" *after* readDataFrom so it doesn't pass the "containing == nil" check above.
		}
		
		// Now add a terminating 'LSTE' item:
		NuTemplateLSTEElement*	tlee;
		tlee = [NuTemplateLSTEElement elementForType:@"LSTE" withLabel:label];
		[containing addObject: tlee];
		[tlee setContaining: containing];
		
		if( bytesToGoAtStart == 0 )		// It's an empty list. Delete this LSTB again, so we only have the empty LSTE.
		{
			[tlee setSubElements: subElements];	// Take over the LSTB's sub-elements.
			[containing removeObject:self];		// Remove the LSTB.
		}
		else
			[tlee setSubElements: [subElements copy]];	// Make a copy. So each has its own array.
	}
}


-(NSString*)	stringValue
{
	return @"";
}


-(IBAction)	showCreateResourceSheet: (id)sender
{
	unsigned			idx = [containing indexOfObject:self];
	NuTemplateElement*	te = [self copy];
	[containing insertObject:te atIndex:idx+1];
	[te setContaining:containing];
}


-(IBAction)	clear: (id)sender
{
	[containing removeObject: self];
	[self autorelease];
}


@end
