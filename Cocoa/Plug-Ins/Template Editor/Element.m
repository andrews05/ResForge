#import "Element.h"

@implementation Element

- (id)initWithType:(NSString *)typeValue andLabel:(NSString *)labelValue
{
	// sets values directly for speed reasons (less messaging overhead)
	self = [super init];
	type = [typeValue copy];
	label = [labelValue copy];
	return self;
}

+ (id)elementOfType:(NSString *)typeValue withLabel:(NSString *)labelValue
{
	Element *element = [[Element allocWithZone:[self zone]] initWithType:typeValue andLabel:labelValue];
	return [element autorelease];
}

- (id)copy
{
	Element *element = [[Element alloc] initWithType:type andLabel:label];
	// copy other stuff here
	return element;
}

/* ACCESSORS */

- (NSString *)label
{
	return label;
}

- (NSString *)type
{
	return type;
}

- (unsigned long)typeAsLong
{
	return *(unsigned long *)[type cString];
}

/* DATA ACCESSORS */

- (NSString *)string
{
	return elementData.string;
}

- (void)setString:(NSString *)string
{
	elementData.string = [string retain];
}

- (NSNumber *)number
{
	return elementData.number;
}

- (void)setNumber:(NSNumber *)number
{
	elementData.number = [number retain];
}

- (long)numberAsLong
{
	return [elementData.number longValue];
}

- (void)setNumberWithLong:(long)number
{
	elementData.number = [[NSNumber numberWithLong:number] retain];
}

- (NSData *)data
{
	return elementData.data;
}

- (void)setData:(NSData *)data
{
	elementData.data = [data retain];
}

- (BOOL)boolean
{
	return elementData.boolean;
}

- (void)setBoolean:(BOOL)boolean
{
	elementData.boolean = boolean;
}

@end
