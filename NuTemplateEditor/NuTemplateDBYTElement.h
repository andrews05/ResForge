//
//  NuTemplateDBYTElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateElement.h"


@interface NuTemplateDBYTElement : NuTemplateElement
{
	char		charValue;
}

-(void)			setCharValue: (char)n;
-(char)			charValue;

-(NSString*)	stringValue;
-(void)			setStringValue: (NSString*)str;

@end
