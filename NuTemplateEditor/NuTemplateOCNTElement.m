//
//  NuTemplateOCNTElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateOCNTElement.h"


static NuTemplateOCNTElement*	sLastParsedElement = nil;


@implementation NuTemplateOCNTElement

+(NuTemplateOCNTElement*)	lastParsedElement
{
	return sLastParsedElement;
}

+(void)	setLastParsedElement: (NuTemplateOCNTElement*)e
{
	NSLog( @"[NuTemplateOCNTElement setLastParsedElement: %@]", e );
	sLastParsedElement = e;
}


-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
		longValue = 0;
	
	[[self class] setLastParsedElement:self];
	
	return self;
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateOCNTElement*	el = [super copyWithZone: zone];
	
	if( el )
	{
		[el setLongValue: longValue];
		[[self class] setLastParsedElement:el];
	}
	
	return el;
}


-(void)	readDataFrom: (NuTemplateStream*)stream
{
	if( [type isEqualToString: @"LCNT"] )
		[stream readAmount:4 toBuffer: &longValue];
	else if( [type isEqualToString: @"LZCT"] )
	{
		[stream readAmount:sizeof(longValue) toBuffer: &longValue];
		longValue += 1;
	}
	else if( [type isEqualToString: @"BCNT"] )
	{
		unsigned char		n = 0;
		[stream readAmount:sizeof(n) toBuffer: &n];
		longValue = n;
	}
	else if( [type isEqualToString: @"BZCT"] )
	{
		char		n = 0;
		[stream readAmount:sizeof(n) toBuffer: &n];
		longValue = n;
	}
	else if( [type isEqualToString: @"ZCNT"] )
	{
		short		n = -1;
		[stream readAmount:sizeof(n) toBuffer: &n];
		longValue = n +1;
	}
	else	// OCNT, WCNT
	{
		unsigned short		n = 0;
		[stream readAmount:sizeof(n) toBuffer: &n];
		longValue = n;
	}
}


-(unsigned int)	sizeOnDisk
{
	if( [type isEqualToString: @"LCNT"] )
		return 4;
	else if( [type isEqualToString: @"LZCT"] )
		return 4;
	else if( [type isEqualToString: @"BZCT"] )
		return 1;
	else if( [type isEqualToString: @"BCNT"] )
		return 1;
	else	// OCNT, WCNT, ZCNT
		return 2;
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	if( [type isEqualToString: @"LCNT"] )
		[stream writeAmount:4 fromBuffer: &longValue];
	else if( [type isEqualToString: @"LZCT"] )
	{
		long		n = longValue -1;
		[stream writeAmount:sizeof(n) fromBuffer: &n];
	}
	else if( [type isEqualToString: @"BZCT"] )
	{
		char		n = longValue -1;
		[stream writeAmount:sizeof(n) fromBuffer: &n];
	}
	else if( [type isEqualToString: @"BCNT"] )
	{
		unsigned char		n = longValue -1;
		[stream writeAmount:sizeof(n) fromBuffer: &n];
	}
	else if( [type isEqualToString: @"ZCNT"] )
	{
		short		n = longValue -1;
		[stream writeAmount:sizeof(n) fromBuffer: &n];
	}
	else	// OCNT, WCNT
	{
		unsigned short		n = longValue;
		[stream writeAmount:sizeof(n) fromBuffer: &n];
	}
}


-(void)	setLongValue: (unsigned long)d
{
	longValue = d;
}

-(unsigned long)	longValue
{
	return longValue;
}


-(NSString*)	stringValue
{
	return [NSString stringWithFormat: @"%ld", longValue];
}


-(void)		setStringValue: (NSString*)str
{
	// Dummy out. User can't change counter this way, they have to add items.
}



@end
