#import "Resource.h"

@implementation Resource

NSString *ResourceChangedNotification = @"ResourceChangedNotification";

- (id)init
{
	self = [super init];
	[self initWithType:@"" andID:[NSNumber numberWithShort:128]];
	return self;
}

- (void)dealloc
{
	[name release];
	[type release];
	[resID release];
	[size release];
	[attributes release];
	[data release];
	[super dealloc];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)newName
{
	[name autorelease];
	name = [newName copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause name changed to %@", ResourceChangedNotification, name );
}

- (NSString *)type
{
	return type;
}

- (void)setType:(NSString *)newType
{
	[type autorelease];
	type = [newType copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause type changed to %@", ResourceChangedNotification, type );
}

- (NSNumber *)resID
{
	return resID;
}

- (void)setResID:(NSNumber *)newResID
{
	[resID autorelease];
	resID = [newResID copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause res ID changed to %@", ResourceChangedNotification, [resID stringValue] );
}

- (NSNumber *)size
{
	return size;
}

- (void)setSize:(NSNumber *)newSize
{
	[size autorelease];
	size = [newSize copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause size changed to %@", ResourceChangedNotification, [size stringValue] );
}

- (NSNumber *)attributes
{
	return attributes;
}

- (void)setAttributes:(NSNumber *)newAttributes
{
	[attributes autorelease];
	attributes = [newAttributes copy];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause attributes changed to %@", ResourceChangedNotification, [attributes stringValue] );
}

- (BOOL)dirty
{
	return dirty;
}

- (void)setDirty:(BOOL)newValue
{
	dirty = newValue;
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause resource became %@", ResourceChangedNotification, dirty? @"dirty":@"clean" );
}

- (NSData *)data
{
	return data;
}

- (void)setData:(NSData *)newData
{
	[data autorelease];
	data = [newData retain];
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceChangedNotification object:self];
//	NSLog( @"%@ posted beacause data changed", ResourceChangedNotification );
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	[self initWithType:typeValue andID:resIDValue withName:@"" andAttributes:[NSNumber numberWithUnsignedShort:0]];
	return self;
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	[self initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:[NSData data] ofLength:[NSNumber numberWithUnsignedLong:0]];
	return self;
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue ofLength:(NSNumber *)sizeValue
{
	[super init];
	[self setName:nameValue];
	[self setType:typeValue];
	[self setResID:resIDValue];
	[self setSize:sizeValue];
	[self setAttributes:attributesValue];
	[self setData:dataValue];
	return self;
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	return [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue];
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	return [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue];
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue ofLength:(NSNumber *)sizeValue
{
	return [[Resource allocWithZone:[self zone]] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:dataValue ofLength:sizeValue];
}


@end
