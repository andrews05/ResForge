//
//  NuTemplateGroupElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateGroupElement.h"


@implementation NuTemplateGroupElement

-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
		subElements = [[NSMutableArray alloc] init];
	
	return self;
}

-(void)	dealloc
{
	[subElements release];
	
	[super dealloc];
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateGroupElement*	el = [super copyWithZone: zone];
	
	if( el )
	{
		NSMutableArray*		arr = [[[NSMutableArray allocWithZone:zone] autorelease] initWithArray:subElements copyItems:YES];
		[el setSubElements: arr];
	}
	
	return el;
}


-(void)		setSubElements: (NSMutableArray*)a
{
	[a retain];
	[subElements release];
	subElements = a;
}

-(NSMutableArray*)	subElements
{
	return subElements;
}

-(int)					subElementCount
{
	return [subElements count];
}

-(NuTemplateElement*)	subElementAtIndex: (int)n
{
	return [subElements objectAtIndex: n];
}

-(void)					readSubElementsFrom: (NuTemplateStream*)stream
{
	NSLog(@"Code for reading this object's sub-elements is missing.");
}


// Before writeDataTo: is called, this is called to calculate the final resource size:
//	This returns the sizes of all our sub-elements. If you subclass, add to that the size
//	of this element itself.
-(unsigned int)			sizeOnDisk
{
	unsigned int		theSize = 0;
	NSEnumerator*		enny = [subElements objectEnumerator];
	NuTemplateElement*	obj;
	
	while( obj = [enny nextObject] )
		theSize += [obj sizeOnDisk];
	
	return theSize;
}

// Writes out the data of all our sub-elements here:
-(void)					writeDataTo: (NuTemplateStream*)stream
{
	NSEnumerator*		enny = [subElements objectEnumerator];
	NuTemplateElement*	obj;
	
	while( obj = [enny nextObject] )
		[obj writeDataTo: stream];
}



@end
