//
//  NuTemplateElement.h
//  ResKnife (PB2)
//
//  Created by Uli Kusterer on Mon Aug 04 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NuTemplateStream.h"

/*
	This is the base class for all template field types. Subclass this to
	define a field type of your own.
	
	Note that subclasses *must* implement the NSCopying protocol, which means
	if you have instance variables, you must provide your own copyWithZone:
	implementation that calls through to the superclass and then copies its
	own variables' values (or retains references to them, if that is more
	effective and the object in question isn't mutable).
*/

@interface NuTemplateElement : NSObject <NSCopying>
{
	NSString*		type;
	NSString*		label;
}

+(id)					elementForType: (NSString*)type withLabel: (NSString*)label;

-(id)					initForType: (NSString*)type withLabel: (NSString*)label;

// Accessors:
-(void)					setType:(NSString*)t;
-(NSString*)			type;

-(void)					setLabel:(NSString*)l;
-(NSString*)			label;

-(NSString*)			stringValue;	// Used to display your data in the list.

// Items that have sub-items (like LSTB, LSTZ, LSTC and other lists) should implement these:
-(int)					subElementCount;
-(NuTemplateElement*)	subElementAtIndex: (int)n;
-(void)					readSubElementsFrom: (NuTemplateStream*)stream;

// This is called on an item of your class when displaying resource data using a template that uses your field:
-(void)					readDataFrom: (NuTemplateStream*)stream containingArray: (NSMutableArray*)containing;

// This is used to instantiate copies of the item from the template for storing data of the resource. A copy created with this is then sent readDataFrom:.
-(id)					copyWithZone: (NSZone*)zone;

// The following are used to write resource data back out:
-(unsigned int)			sizeOnDisk;
-(void)					writeDataTo: (NuTemplateStream*)stream;


@end
