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


-(void)	readDataFrom: (NuTemplateStream*)stream containingArray: (NSMutableArray*)containing
{
	NSEnumerator		*enny = [subElements objectEnumerator];
	NuTemplateElement	*el, *nextItem;
	
	// Fill this first list element with data:
	while( el = [enny nextObject] )
	{
		[el readDataFrom: stream containingArray: subElements];
	}
	
	// Read additional elements until we have enough items:
	if( containing != nil )
	{
		while( [stream bytesToGo] > 0 )
		{
			nextItem = [self copy];				// Make another list item just like this one.
			[containing addObject: nextItem];	// Add it below ourselves.
			[nextItem readDataFrom:stream containingArray:nil];	// Read it the same way we were.
		}
		
		// Now add a terminating 'LSTE' item:
		NuTemplateLSTEElement*	tlee;
		tlee = [NuTemplateLSTEElement elementForType:@"LSTE" withLabel:label];
		[containing addObject: tlee];
		[tlee setSubElements: [subElements copy]];
	}
}


@end
