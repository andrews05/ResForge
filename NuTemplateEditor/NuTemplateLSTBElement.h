//
//  NuTemplateLSTBElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "NuTemplateGroupElement.h"


@class NuTemplateLSTEElement;


@interface NuTemplateLSTBElement : NuTemplateGroupElement
{
	NuTemplateLSTEElement*		endElement;		// Template to create our "list end" element from.
}

-(IBAction)	showCreateResourceSheet: (id)sender;

-(void)						setEndElement: (NuTemplateLSTEElement*)e;
-(NuTemplateLSTEElement*)	endElement;

@end
