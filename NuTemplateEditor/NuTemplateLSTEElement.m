//
//  NuTemplateLSTEElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateLSTEElement.h"


@implementation NuTemplateLSTEElement


-(void)		readSubElementsFrom: (NuTemplateStream*)stream
{
	
}


-(void)	readDataFrom: (NuTemplateStream*)stream containingArray: (NSMutableArray*)containing
{
	NSEnumerator*		enny = [subElements objectEnumerator];
	NuTemplateElement*	el;
	
	while( el = [enny nextObject] )
	{
		[el readDataFrom: stream containingArray: subElements];
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



@end
