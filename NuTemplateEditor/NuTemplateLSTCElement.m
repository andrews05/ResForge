//
//  NuTemplateLSTCElement.m
//  ResKnife (PB2)
//
//	Implements LSTB and LSTZ fields.
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateLSTCElement.h"
#import "NuTemplateLSTEElement.h"
#import "NuTemplateOCNTElement.h"


@implementation NuTemplateLSTCElement

-(void)	dealloc
{
	[endElement release];
	[super dealloc];
}


-(void)		readSubElementsFrom: (NuTemplateStream*)stream
{
	countElement = [NuTemplateOCNTElement lastParsedElement];
	
	while( [stream bytesToGo] > 0 )
	{
		NuTemplateElement*	obj = [stream readOneElement];
		
		if( [[obj type] isEqualToString: @"LSTE"] )
		{
			endElement = [obj retain];
			break;
		}
		[subElements addObject: obj];
	}
}


-(void)	readDataForElements: (NuTemplateStream*)stream
{
	NSEnumerator		*enny = [subElements objectEnumerator];
	NuTemplateElement	*el;
	
	while( el = [enny nextObject] )
	{
		[el readDataFrom: stream];
	}
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	NSEnumerator		*enny = [subElements objectEnumerator];
	NuTemplateElement	*el, *nextItem;
	unsigned int		itemsToGo = 0,
						itemsToGoAtStart = 0;
	
	countElement = [NuTemplateOCNTElement lastParsedElement];
	NSLog( @"countElement: %@", countElement );
	
	itemsToGo = [countElement longValue];
	itemsToGoAtStart = itemsToGo;
	NSLog( @"LSTC: Number of items: %ld", itemsToGo );
	
	// Read a first item:
	if( itemsToGo > 0 )
	{
		[self readDataForElements: stream];
		itemsToGo--;
	}
	
	/* Read additional elements until we have enough items,
		except if we're not the first item in our list. */
	if( containing != nil )
	{
		while( itemsToGo-- )
		{
			// Actually read the item:
			nextItem = [[self copy] autorelease];	// Make another list item just like this one.
			[nextItem setContaining: nil];			// Make sure it doesn't get into this "if" clause.
			[containing addObject: nextItem];		// Add it below ourselves.
			[nextItem readDataFrom:stream];			// Read it the same way we were.
			[nextItem setContaining: containing];	// Set "containing" *after* readDataFrom so it doesn't pass the "containing == nil" check above.
		}
		
		// Now add a terminating 'LSTE' item:
		NuTemplateLSTEElement*	tlee;
		tlee = [[endElement copy] autorelease];
		[containing addObject: tlee];
		[tlee setContaining: containing];
		[tlee setGroupElemTemplate: self];
		[tlee setCountElement: countElement];
		[tlee readDataFrom: stream];	// If LSTE has data to read (e.g. if we're an LSTZ, the terminating byte), let it do that!
		
		if( itemsToGoAtStart == 0 )		// It's an empty list. Delete this LSTC again, so we only have the empty LSTE.
		{
			[tlee setSubElements: subElements];	// Take over the LSTC's sub-elements.
			[containing removeObject:self];		// Remove the LSTB.
		}
		else
			[tlee setSubElements: [[subElements copy] autorelease]];	// Make a copy. So each has its own array.
	}
}


-(NSString*)	stringValue
{
	return @"";
}


-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateLSTCElement*	el = [super copyWithZone: zone];
	
	[el setEndElement: [self endElement]];
	[el setCountElement: [self countElement]];
	
	return el;
}


-(void)	setEndElement: (NuTemplateLSTEElement*)e
{
	[e retain];
	[endElement release];
	endElement = e;
}

-(NuTemplateLSTEElement*)	endElement
{
	return endElement;
}


-(void)	setCountElement: (NuTemplateOCNTElement*)e
{
	countElement = e;
}

-(NuTemplateOCNTElement*)	countElement
{
	return countElement;
}


-(IBAction)	showCreateResourceSheet: (id)sender
{
	unsigned				idx = [containing indexOfObject:self];
	NuTemplateGroupElement*	te = [[self copy] autorelease];
	
	[containing insertObject:te atIndex:idx+1];
	[te setContaining:containing];
	
	// Update "counter" item:
	[countElement setLongValue: ([countElement longValue] +1)];
}


-(IBAction)	clear: (id)sender
{
	[[self retain] autorelease];		// Make sure we don't go away right now. That may surprise the one who called clear, or otherwise be bad.
	[containing removeObject: self];	// Remove us from the array we're in. (this releases us once)
	
	[countElement setLongValue: [countElement longValue] -1];
}


@end
