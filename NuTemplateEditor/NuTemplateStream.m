//
//  NuTemplateStream.m
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateStream.h"
#import "NuTemplateElement.h"


@implementation NuTemplateStream

+(NSMutableDictionary*)	fieldRegistry
{
	static NSMutableDictionary*		sFieldRegistry = nil;
	
	if( !sFieldRegistry )
		sFieldRegistry = [[NSMutableDictionary alloc] init];
	
	return sFieldRegistry;
}

+(id)	streamWithBytes: (char*)d length: (unsigned int)l
{
	return [[[self alloc] autorelease] initStreamWithBytes:d length:l];
}

+(id)	substreamWithStream: (NuTemplateStream*)s length: (unsigned int)l
{
	return [[[self alloc] autorelease] initWithStream:s length:l];
}


-(id)	initStreamWithBytes: (char*)d length: (unsigned int)l
{
	if( self = [super init] )
	{
		data = d;
		bytesToGo = l;
	}
	
	return self;
}

-(id)	initWithStream: (NuTemplateStream*)s length: (unsigned int)l
{
	if( self = [super init] )
	{
		data = [s data];
		if( l > [s bytesToGo] )
			bytesToGo = [s bytesToGo];
		else
			bytesToGo = l;
	}
	
	return self;
}


-(unsigned int)			bytesToGo
{
	return bytesToGo;
}


-(char*)				data
{
	return data;
}


-(NuTemplateElement*)	readOneElement
{
	NSString*			label = [NSString stringWithCString: data +1 length: *data];
	unsigned long		labelLen = (*data) +1;
	NuTemplateElement*	obj = nil;
	data += labelLen;
	
	// Get type (4 characters after that):
	NSString*		type = [NSString stringWithCString: data length: 4];
	data += 4;
	
	// Update number of bytes left: (termination criterion!)
	bytesToGo -= labelLen +4;
	
	// TODO: We should really look up the class for an entry of this type in a dictionary:
	Class	theClass = [[NuTemplateStream fieldRegistry] objectForKey:type];
	obj = (NuTemplateElement*) [theClass elementForType:type withLabel:label];
	[obj readSubElementsFrom: self];
	
	return obj;
}


-(void)	readAmount: (unsigned int)l toBuffer: (void*)buf
{
	if( l > bytesToGo )
		l = bytesToGo;
	
	if( l > 0 )
	{
		memmove( buf, data, l );
		data += l;
		bytesToGo -= l;
	}
}


-(void)	peekAmount: (unsigned int)l toBuffer: (void*)buf
{
	if( l > bytesToGo )
		l = bytesToGo;
	
	if( l > 0 )
		memmove( buf, data, l );
}


-(void)	writeAmount: (unsigned int)l fromBuffer: (void*)buf
{
	if( l > bytesToGo )
		l = bytesToGo;
	
	if( l > 0 )
	{
		memmove( data, buf, l );
		data += l;
		bytesToGo -= l;
	}
}


@end
