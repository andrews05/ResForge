//
//  NuTemplateLSTEElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "NuTemplateGroupElement.h"

@class NuTemplateOCNTElement;

@interface NuTemplateLSTEElement : NuTemplateGroupElement
{
	NuTemplateGroupElement*		groupElemTemplate;	// The item of which we're to create a copy.
	NuTemplateOCNTElement*		countElement;		// The "counter" element if we're the end of an LSTC list.
	BOOL						writesZeroByte;		// Write a terminating zero-byte when writing out this item (used by LSTZ).
}

-(IBAction)	showCreateResourceSheet: (id)sender;

-(void)						setWritesZeroByte: (BOOL)n;
-(BOOL)						writesZeroByte;

-(void)						setGroupElemTemplate: (NuTemplateGroupElement*)e;
-(NuTemplateGroupElement*)	groupElemTemplate;

-(void)						setCountElement: (NuTemplateOCNTElement*)e;
-(NuTemplateOCNTElement*)	countElement;

@end
