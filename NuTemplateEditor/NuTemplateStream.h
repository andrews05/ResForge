//
//  NuTemplateStream.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>


@class	NuTemplateElement;


@interface NuTemplateStream : NSObject
{
	unsigned int		bytesToGo;
	char*				data;
}

+(NSMutableDictionary*)	fieldRegistry;

+(id)					streamWithBytes: (char*)d length: (unsigned int)l;
+(id)					substreamWithStream: (NuTemplateStream*)s length: (unsigned int)l;

-(id)					initStreamWithBytes: (char*)d length: (unsigned int)l;
-(id)					initWithStream: (NuTemplateStream*)s length: (unsigned int)l;

-(unsigned int)			bytesToGo;
-(char*)				data;

-(NuTemplateElement*)	readOneElement;		// For parsing of 'TMPL' resource as template.
-(void)					readAmount: (unsigned int)l toBuffer: (void*)buf;	// For reading data from the resource.

-(void)					writeAmount: (unsigned int)l fromBuffer: (void*)buf;	// For writing data back to the resource.

@end
