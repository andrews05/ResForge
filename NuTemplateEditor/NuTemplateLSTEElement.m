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

-(void)	dealloc
{
	[groupElemTemplate release];
	[super dealloc];
}


-(void)	setGroupElemTemplate: (NuTemplateGroupElement*)e
{
	[e retain];
	[groupElemTemplate release];
	groupElemTemplate = e;
}

-(NuTemplateGroupElement*)	groupElemTemplate
{
	return groupElemTemplate;
}


-(void)		readSubElementsFrom: (NuTemplateStream*)stream
{
	
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	if( writesZeroByte )
	{
		char	termByte;
		[stream readAmount:1 toBuffer: &termByte];
	}
}


// Doesn't write any sub-elements because this is simply a placeholder to allow for empty lists:
-(unsigned int)	sizeOnDisk
{
	return writesZeroByte ? 1 : 0;
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	if( writesZeroByte )
	{
		char		fillByte = 0;
		[stream writeAmount:sizeof(fillByte) fromBuffer: &fillByte];
	}
}


-(int)	subElementCount
{
	return 0;	// We don't want the user to be able to uncollapse us to see our sub-items.
}


-(NSString*)	stringValue
{
	return @"";
}


-(void)	setWritesZeroByte: (BOOL)n
{
	writesZeroByte = n;
}

-(BOOL)	writesZeroByte
{
	return writesZeroByte;
}


-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateLSTEElement*	el = [super copyWithZone: zone];
	
	[el setGroupElemTemplate: [self groupElemTemplate]];
	[el setWritesZeroByte: [self writesZeroByte]];
	
	return el;
}


-(IBAction)	showCreateResourceSheet: (id)sender
{
	unsigned				idx = [containing indexOfObject:self];
	NuTemplateGroupElement*	ge = [[groupElemTemplate copy] autorelease];

	[containing insertObject:ge atIndex:idx];
	[ge setContaining: containing];
}




@end
