#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"

NSString *RKResourcePboardType		= @"RKResourcePboardType";

@implementation Resource

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
	representedFork = nil;
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

+ (Resource *)getResourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)document
{
	NSDocument *doc;
	NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
	while( doc = [enumerator nextObject] )
	{
		if( document == nil || document == doc )
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue andID:resIDValue];
			if( resource ) return resource;
		}
	}
	return nil;
}

/* ResKnifeResourceProtocol implementation */

+ (NSArray *)allResourcesOfType:(NSString *)typeValue inDocument:(NSDocument *)document
{
	NSMutableArray *array = [NSMutableArray array];
	NSDocument *doc;
	NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
	while( doc = [enumerator nextObject] )
	{
		// parse document for resources
		if( document == nil || document == doc )
			[array addObjectsFromArray:[[(ResourceDocument *)doc dataSource] allResourcesOfType:typeValue]];
	}
	return [NSArray arrayWithArray:array];
}

+ (Resource *)resourceOfType:(NSString *)typeValue withName:(NSString *)nameValue inDocument:(NSDocument *)document
{
	NSDocument *doc;
	NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
	while( doc = [enumerator nextObject] )
	{
		if( document == nil || document == doc )
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue withName:nameValue];
			if( resource ) return resource;
		}
	}
	return nil;
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)document
{
	NSDocument *doc;
	NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
	while( doc = [enumerator nextObject] )
	{
		if( document == nil || document == doc )
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue andID:resIDValue];
			if( resource ) return resource;
		}
	}
	return nil;
}

- (void)dealloc
{
	[representedFork release];
	[name release];
	[type release];
	[resID release];
	[attributes release];
	[data release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	Resource *copy = [[Resource alloc] initWithType:type andID:resID withName:name andAttributes:attributes data:[data copy]];
	return copy;
}

/* Accessors */

- (void)touch
{
	[self setDirty:YES];
}

- (BOOL)isDirty
{
	return dirty;
}

- (void)setDirty:(BOOL)newValue
{
	dirty = newValue;
	[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDidChangeNotification object:self];
}

- (NSString *)representedFork
{
	return representedFork;
}

- (void)setRepresentedFork:(NSString *)forkName
{
	representedFork = [forkName copy];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)newName
{
	if( ![name isEqualToString:newName] )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameWillChangeNotification object:self];
		
		[name autorelease];
		name = [newName copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSString *)type
{
	return type;
}

- (void)setType:(NSString *)newType
{
	if( ![type isEqualToString:newType] )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeWillChangeNotification object:self];
		
		[type autorelease];
		type = [newType copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSNumber *)resID
{
	return resID;
}

- (void)setResID:(NSNumber *)newResID
{
	if( ![resID isEqualToNumber:newResID] )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDWillChangeNotification object:self];
		
		[resID autorelease];
		resID = [newResID copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSNumber *)attributes
{
	return attributes;
}

- (void)setAttributes:(NSNumber *)newAttributes
{
	if( ![attributes isEqualToNumber:newAttributes] )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesWillChangeNotification object:self];
		
		[attributes autorelease];
		attributes = [newAttributes copy];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesDidChangeNotification object:self];
		[self setDirty:YES];
	}
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
	if( ![data isEqualToData:newData] )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataWillChangeNotification object:self];
		
		// note: this function retains, rather than copies, the supplied data
		[data autorelease];
		data = [newData retain];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

/* encoding */

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	if( self )
	{
		dirty = YES;
		name = [[decoder decodeObject] retain];
		type = [[decoder decodeObject] retain];
		resID = [[decoder decodeObject] retain];
		attributes = [[decoder decodeObject] retain];
		data = [[decoder decodeDataObject] retain];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:name];
	[encoder encodeObject:type];
	[encoder encodeObject:resID];
	[encoder encodeObject:attributes];
	[encoder encodeDataObject:data];
}

/* description */

- (NSString *)description
{
	return [NSString stringWithFormat:@"\n%@\nName: %@\nType: %@  ID: %@\nSize: %d  Modified: %@", [super description], name, type, resID, [data length], dirty? @"YES":@"NO"];
}

@end
