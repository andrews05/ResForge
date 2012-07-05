#import "Element.h"

@implementation Element

+ (id)elementForType:(NSString *)t withLabel:(NSString *)l
{
	return [[[self alloc]initForType:t withLabel:l] autorelease];
}

- (id)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super init];
	if(!self) return nil;
	label = [l copy];
	type = [t copy];
	return self;
}

- (void)dealloc
{
	[label release];
	[type release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	Element *element = [[[self class] allocWithZone:zone] initForType:type withLabel:label];
	[element setParentArray:parentArray];
	return element;
}

#pragma mark -

- (void)setIsTMPL:(BOOL)t
{
	_isTMPL = t;
}

- (BOOL)isTMPL
{
	return _isTMPL;
}

- (void)setType:(NSString *)t
{
	id old = type;
	type = [t copy];
	[old release];
}

- (NSString *)type
{
	return type;
}

- (void)setLabel:(NSString *)l
{
	id old = label;
	label = [l copy];
	[old release];
}

- (NSString *)label
{
	return label;
}

- (void)setParentArray:(NSMutableArray *)array
{
	// do not retain parent object
	parentArray = array;
}

- (NSMutableArray *)parentArray
{
	return parentArray;
}

/*** METHODS SUBCLASSES SHOULD OVERRIDE ***/

- (int)subElementCount
{
	// default implementation suitable for most element types
	return 0;
}

- (Element *)subElementAtIndex:(int)n
{
	// default implementation suitable for most element types
	return nil;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	// by default, items don't read any sub-elements.
}

// You should read whatever kind of data your template field stands for from "stream"
//	and store it in an instance variable.
- (void)readDataFrom:(TemplateStream *)stream
{
	NSLog(@"-readDataFrom:called on non-concrete class Element");
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	Items with sub-elements should return the sum of the sizes of all their sub-elements here as well.
- (unsigned int)sizeOnDisk
{
	// default implementation suitable for dimentionless element types
	return 0;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	NSLog(@"-writeDataTo:called on non-concrete class Element");
}

- (NSString *)stringValue
{
	NSLog(@"-stringValue called on non-concrete class Element");
	return @"<unknown>";
}

- (void)setStringValue:(NSString *)value
{
	// we need this method, otherwise KVC throws an exception which screws up the table
	NSLog(@"-setStringValue:@\"%@\" called on non-concrete class Element", value);
}

- (BOOL)editable
{
	// override this for non-editable field types
	return YES;
}

- (float)rowHeight
{
	return 18.0;
}

@end
