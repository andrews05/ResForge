//
//  NuTemplateTNAMElement.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateTNAMElement.h"


@implementation NuTemplateTNAMElement

-(id)	initForType: (NSString*)t withLabel: (NSString*)l
{
	if( self = [super initForType:t withLabel:l] )
		stringValue = [[NSString alloc] init];
	
	return self;
}

-(void)	dealloc
{
	[stringValue release];
	
	[super dealloc];
}

-(id)	copyWithZone: (NSZone*)zone
{
	NuTemplateTNAMElement*	el = [super copyWithZone: zone];
	
	if( el )
		[el setStringValue: stringValue];
	
	return el;
}


-(void)	readDataFrom: (NuTemplateStream*)stream containingArray: (NSMutableArray*)containing
{
	char		buf[4] = { ' ', ' ', ' ', ' ' };
	
	[stream readAmount:4 toBuffer: buf];
	
	[self setStringValue: [NSString stringWithCString:buf length:4]];

	NSLog(@"PSTR: %@", stringValue);
}


// Before writeDataTo: is called, this is called to calculate the final resource size:
-(unsigned int)	sizeOnDisk
{
	return 4;
}

-(void)	writeDataTo: (NuTemplateStream*)stream
{
	char		buf[5] = { ' ', ' ', ' ', ' ', 0 };
	
	[stringValue getCString:buf maxLength:4];
	[stream writeAmount:4 fromBuffer:buf];
}


-(void)	setStringValue: (NSString*)d
{
	[d retain];
	[stringValue release];
	stringValue = d;
}


-(NSString*)	stringValue
{
	return stringValue;
}



@end
