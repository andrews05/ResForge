//
//  NuTemplateGroupElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Tue Aug 05 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "NuTemplateElement.h"


@interface NuTemplateGroupElement : NuTemplateElement
{
	NSMutableArray*		subElements;
}

-(void)				setSubElements: (NSMutableArray*)a;
-(NSMutableArray*)	subElements;

@end
