//
//  NuTemplateDBYTElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateDBYTElement.h"


@implementation NuTemplateDBYTElement

-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
	{
		if( [l isEqualToString: @"CHAR"] )
			charValue = ' ';
		else
			charValue = 0;
	}
	
	return self;
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateDBYTElement*	el = [super copyWithZone: zone];
	
	if( el )
		[el setCharValue: charValue];
	
	return el;
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	[stream readAmount:2 toBuffer: &charValue];
}


-(unsigned int)	sizeOnDisk
{
	return sizeof(charValue);
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	[stream writeAmount:sizeof(charValue) fromBuffer: &charValue];
}


-(void)	setCharValue: (char)d
{
	charValue = d;
}

-(char)	charValue
{
	return charValue;
}


-(NSString*)	stringValue
{
	if( [l isEqualToString: @"CHAR"] )
		return [NSString stringWithCString:&charValue length:1];
	else
		return [NSString stringWithFormat: @"%d", charValue];
}


-(void)		setStringValue: (NSString*)str
{
	if( [l isEqualToString: @"CHAR"] )
		charValue = [str cString][0];
	else
	{
		char		cstr[256];
		char*		endPtr = cstr +255;
		
		strncpy( cstr, [str cString], 255 );
		charValue = strtol( cstr, &endPtr, 10 );
	}
}



@end
