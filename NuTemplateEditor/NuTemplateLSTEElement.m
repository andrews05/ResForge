//
//  NuTemplateLSTEElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateLSTEElement.h"
#import "NuTemplateLSTBElement.h"


@implementation NuTemplateLSTEElement


-(void)		readSubElementsFrom: (NuTemplateStream*)stream
{
	
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	NSEnumerator*		enny = [subElements objectEnumerator];
	NuTemplateElement*	el;
	
	while( el = [enny nextObject] )
	{
		[el readDataFrom: stream];
	}
}


// Doesn't write any sub-elements because this is simply a placeholder to allow for empty lists:
-(unsigned int)	sizeOnDisk
{
	return 0;
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	
}


-(int)	subElementCount
{
	return 0;	// We don't want the user to be able to uncollapse us to see our sub-items.
}


-(NSString*)	stringValue
{
	return @"";
}


-(IBAction)	showCreateResourceSheet: (id)sender
{
	unsigned				idx = [containing indexOfObject:self];
	NuTemplateGroupElement*	ge = [NuTemplateLSTBElement elementForType:@"LSTB" withLabel:[self label]];

	[ge setSubElements: [subElements copy]];
	[containing insertObject:ge atIndex:idx];
	[ge setContaining: containing];
}




@end
