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
	NSString*		type;			// Type code of this item (4 chars if from TMPL resource, but we may support longer types later).
	NSString*		label;			// Label ("name") of this field.
	NSMutableArray*	containing;		// The NSMutableArray* of the template field containing us, or the template window's list.
}

+(id)					elementForType: (NSString*)type withLabel: (NSString*)label;

-(id)					initForType: (NSString*)type withLabel: (NSString*)label;

// Accessors:
-(void)					setType:(NSString*)t;
-(NSString*)			type;

-(void)					setLabel:(NSString*)l;
-(NSString*)			label;

-(void)					setContaining: (NSMutableArray*)arr;
-(NSMutableArray*)		containing;

-(NSString*)			stringValue;	// Used to display your data in the list.

// Items that have sub-items (like LSTB, LSTZ, LSTC and other lists) should implement these:
-(int)					subElementCount;
-(NuTemplateElement*)	subElementAtIndex: (int)n;
-(void)					readSubElementsFrom: (NuTemplateStream*)stream;

// This is called on an item of your class when displaying resource data using a template that uses your field:
-(void)					readDataFrom: (NuTemplateStream*)stream;

// This is used to instantiate copies of the item from the template for storing data of the resource. A copy created with this is then sent readDataFrom:.
-(id)					copyWithZone: (NSZone*)zone;

// The following are used to write resource data back out:
-(unsigned int)			sizeOnDisk;
-(void)					writeDataTo: (NuTemplateStream*)stream;

/* Apart from these messages, a NuTemplateElement may also implement the IBActions for
	the standard edit commands (cut, copy, paste, clear). When an element is selected,
	the template editor will forward any calls to these items to the element, if it
	implements them, and it will automatically enable the appropriate menu items. It
	will also forward validateMenuItem: for the Paste menu item to the element.
	
	The showCreateResourceSheet: action will also be forwarded to elements by the
	template editor. Use this to allow creating new list items or for similar
	purposes ("Create New Resource..." is renamed to "Create List Entry" while the
	template editor is key). */

@end
