#import "Resource.h"

@implementation Resource

// should these be above or below "@implementation Resource" ?
NSString *ResourceWillChangeNotification			= @"ResourceWillChangeNotification";
NSString *ResourceNameWillChangeNotification		= @"ResourceNameWillChangeNotification";
NSString *ResourceTypeWillChangeNotification		= @"ResourceTypeWillChangeNotification";
NSString *ResourceIDWillChangeNotification			= @"ResourceIDWillChangeNotification";
NSString *ResourceAttributesWillChangeNotification	= @"ResourceAttributesWillChangeNotification";
NSString *ResourceDataWillChangeNotification		= @"ResourceDataWillChangeNotification";

NSString *ResourceNameDidChangeNotification			= @"ResourceNameDidChangeNotification";
NSString *ResourceTypeDidChangeNotification			= @"ResourceTypeDidChangeNotification";
NSString *ResourceIDDidChangeNotification			= @"ResourceIDDidChangeNotification";
NSString *ResourceAttributesDidChangeNotification	= @"ResourceAttributesDidChangeNotification";
NSString *ResourceDataDidChangeNotification			= @"ResourceDataDidChangeNotification";
NSString *ResourceDidChangeNotification				= @"ResourceDidChangeNotification";

- (id)init
{
	self = [super init];
	[self initWithType:@"NULL" andID:[NSNumber numberWithShort:128]];
	return self;
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	[self initWithType:typeValue andID:resIDValue withName:@"" andAttributes:[NSNumber numberWithUnsignedShort:0]];
	return self;
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	[self initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:[NSData data]];
	return self;
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue
{
	// sets values directly for speed reasons (less messaging overhead)
	self = [super init];
	dirty = NO;
	name = [nameValue copy];
	type = [typeValue copy];
	resID = [resIDValue copy];
	attributes = [attributesValue copy];
	data = [dataValue retain];
	return self;
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	Resource *resource = [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue];
	return [resource autorelease];
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	Resource *resource = [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue];
	return [resource autorelease];
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue
{
	Resource *resource = [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:dataValue];
	return [resource autorelease];
}

- (void)dealloc
{
	[name release];
	[type release];
	[resID release];
	[attributes release];
	[data release];
	[super dealloc];
}

/* Accessors */

- (BOOL)isDirty
{
	return dirty;
}

- (void)setDirty:(BOOL)newValue
{
	dirty = newValue;
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDidChangeNotification object:self];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)newName
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameWillChangeNotification object:self];
	
	[name autorelease];
	name = [newName copy];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameDidChangeNotification object:self];
	[self setDirty:YES];
}

- (NSString *)type
{
	return type;
}

- (void)setType:(NSString *)newType
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeWillChangeNotification object:self];
	
	[type autorelease];
	type = [newType copy];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeDidChangeNotification object:self];
	[self setDirty:YES];
}

- (NSNumber *)resID
{
	return resID;
}

- (void)setResID:(NSNumber *)newResID
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDWillChangeNotification object:self];
	
	[resID autorelease];
	resID = [newResID copy];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDDidChangeNotification object:self];
	[self setDirty:YES];
}

- (NSNumber *)attributes
{
	return attributes;
}

- (void)setAttributes:(NSNumber *)newAttributes
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesWillChangeNotification object:self];
	
	[attributes autorelease];
	attributes = [newAttributes copy];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesDidChangeNotification object:self];
	[self setDirty:YES];
}

- (NSNumber *)size
{
	return [NSNumber numberWithUnsignedLong:[data length]];
}

- (NSData *)data
{
	return data;
}

- (void)setData:(NSData *)newData
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataWillChangeNotification object:self];
	
	// note: this function retains, rather than copies, the supplied data
	[data autorelease];
	data = [newData retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:self];
	[self setDirty:YES];
}

@end
