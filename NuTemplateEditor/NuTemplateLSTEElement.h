//
//  NuTemplateLSTEElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "NuTemplateGroupElement.h"


@interface NuTemplateLSTEElement : NuTemplateGroupElement
{
	NuTemplateGroupElement*		groupElemTemplate;	// The item of which we're to create a copy.
}

-(IBAction)	showCreateResourceSheet: (id)sender;

-(void)						setGroupElemTemplate: (NuTemplateGroupElement*)e;
-(NuTemplateGroupElement*)	groupElemTemplate;

@end
