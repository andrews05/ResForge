//
//  NuTemplateDWRDElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateDWRDElement.h"


@implementation NuTemplateDWRDElement

-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
		shortValue = 0;
	
	return self;
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateDWRDElement*	el = [super copyWithZone: zone];
	
	if( el )
		[el setShortValue: shortValue];
	
	return el;
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	[stream readAmount:2 toBuffer: &shortValue];
}


-(unsigned int)	sizeOnDisk
{
	return 2;
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	[stream writeAmount:2 fromBuffer: &shortValue];
}


-(void)	setShortValue: (short)d
{
	shortValue = d;
}

-(short)	shortValue
{
	return shortValue;
}


-(NSString*)	stringValue
{
	return [NSString stringWithFormat: @"%d", shortValue];
}


-(void)		setStringValue: (NSString*)str
{
	char		cstr[256];
	char*		endPtr = cstr +255;
	
	strncpy( cstr, [str cString], 255 );
	shortValue = strtol( cstr, &endPtr, 10 );
}



@end
