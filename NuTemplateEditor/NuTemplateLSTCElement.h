//
//  NuTemplateLSTCElement.h
//  ResKnife (PB2)
//
//	Implements LSTB and LSTZ fields.
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "NuTemplateGroupElement.h"


@class NuTemplateLSTEElement;
@class NuTemplateOCNTElement;


@interface NuTemplateLSTCElement : NuTemplateGroupElement
{
	NuTemplateLSTEElement*		endElement;		// Template to create our "list end" element from.
	NuTemplateOCNTElement*		countElement;	// Our "list counter" element.
}

-(IBAction)	showCreateResourceSheet: (id)sender;

-(void)						setEndElement: (NuTemplateLSTEElement*)e;
-(NuTemplateLSTEElement*)	endElement;

-(void)						setCountElement: (NuTemplateOCNTElement*)e;
-(NuTemplateOCNTElement*)	countElement;

@end
