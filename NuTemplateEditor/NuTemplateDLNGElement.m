//
//  NuTemplateDLNGElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateDLNGElement.h"


@implementation NuTemplateDLNGElement

-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
		longValue = 0;
	
	return self;
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateDLNGElement*	el = [super copyWithZone: zone];
	
	if( el )
		[el setLongValue: longValue];
	
	return el;
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	[stream readAmount:sizeof(longValue) toBuffer: &longValue];
}


-(unsigned int)	sizeOnDisk
{
	return sizeof(longValue);
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	[stream writeAmount:sizeof(longValue) fromBuffer: &longValue];
}


-(void)	setLongValue: (long)d
{
	longValue = d;
}

-(long)	longValue
{
	return longValue;
}


-(NSString*)	stringValue
{
	return [NSString stringWithFormat: @"%ld", longValue];
}


-(void)		setStringValue: (NSString*)str
{
	char		cstr[256];
	char*		endPtr = cstr +255;
	
	strncpy( cstr, [str cString], 255 );
	longValue = strtol( cstr, &endPtr, 10 );
}



@end
