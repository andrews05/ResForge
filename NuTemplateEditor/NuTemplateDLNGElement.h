//
//  NuTemplateDLNGlement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateElement.h"


@interface NuTemplateDLNGElement : NuTemplateElement
{
	long		longValue;
}

-(void)			setLongValue: (long)n;
-(long)			longValue;

-(NSString*)	stringValue;
-(void)			setStringValue: (NSString*)str;

@end
