//
//  NuTemplateDWRDElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateElement.h"


@interface NuTemplateDWRDElement : NuTemplateElement
{
	short		shortValue;
}

-(void)			setShortValue: (short)n;
-(short)		shortValue;

-(NSString*)	stringValue;

@end
