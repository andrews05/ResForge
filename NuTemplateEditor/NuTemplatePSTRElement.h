//
//  NuTemplatePSTRElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateElement.h"


@interface NuTemplatePSTRElement : NuTemplateElement
{
	NSString*		stringValue;
}

-(void)			setStringValue: (NSString*)d;
-(NSString*)	stringValue;

@end
