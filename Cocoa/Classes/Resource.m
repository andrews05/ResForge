#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"

NSString *RKResourcePboardType = @"RKResourcePboardType";

@implementation Resource

- (id)init
{
	return self = [self initWithType:@"NULL" andID:@(128)];
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	return [self initWithType:typeValue andID:resIDValue withName:@"" andAttributes:@(0)];
}

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	return [self initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:[NSData data]];
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
	data = dataValue;
	return self;
}


+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue];
	return resource;
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue];
	return resource;
}

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:dataValue];
	return resource;
}

+ (Resource *)getResourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)searchDoc
{
	for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if(searchDoc == nil || searchDoc == doc)
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue andID:resIDValue];
			if(resource) return resource;
		}
	}
	return nil;
}

/* ResKnifeResourceProtocol implementation */

+ (NSArray *)allResourcesOfType:(NSString *)typeValue inDocument:(NSDocument *)searchDoc
{
	NSMutableArray *array = [NSMutableArray array];
	for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents])
	{
		// parse document for resources
		if(searchDoc == nil || searchDoc == doc)
			[array addObjectsFromArray:[[(ResourceDocument *)doc dataSource] allResourcesOfType:typeValue]];
	}
	return [NSArray arrayWithArray:array];
}

+ (Resource *)resourceOfType:(NSString *)typeValue withName:(NSString *)nameValue inDocument:(NSDocument *)searchDoc
{
	for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if(searchDoc == nil || searchDoc == doc)
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue withName:nameValue];
			if(resource) return resource;
		}
	}
	return nil;
}

+ (Resource *)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)searchDoc
{
	for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if(searchDoc == nil || searchDoc == doc)
		{
			// parse document for correct resource
			Resource *resource = [[(ResourceDocument *)doc dataSource] resourceOfType:typeValue andID:resIDValue];
			if(resource) return resource;
		}
	}
	return nil;
}

// should probably be in resource document, not resource, but it fits in with the above methods quite well
+ (NSDocument *)documentForResource:(Resource *)resource
{
	for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents])
	{
		Resource *res;
		NSEnumerator *enumerator2 = [[(ResourceDocument *)doc resources] objectEnumerator];
		while(res = [enumerator2 nextObject])
		{
			if([res isEqual:resource])
				return doc;
		}
	}
	return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
	Resource *copy = [[Resource alloc] initWithType:type andID:resID withName:name andAttributes:attributes data:[data copy]];
	[copy setDocumentName:_docName];
	return copy;
}

/* accessors */

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

- (NSDocument *)document
{
	return [Resource documentForResource:self];
}

- (void)setDocumentName:(NSString *)docName
{
	_docName = [docName copy];
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

// shouldn't need this - it's used by forks to give them alternate names - should use name formatter replacement instead
- (void)_setName:(NSString *)newName
{
	name = [newName copy];
}

- (void)setName:(NSString *)newName
{
	if(![name isEqualToString:newName])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameWillChangeNotification object:self];
		
		name = [newName copy];
		
		// bug: this line is causing crashes!
//		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSString *)defaultWindowTitle
{
	if([name length] > 0)	return [NSString stringWithFormat: NSLocalizedString(@"%@: %@ %@ '%@'", @"default window title format with resource name"), _docName, type, resID, name];
	else					return [NSString stringWithFormat: NSLocalizedString(@"%@: %@ %@", @"default window title format without resource name"), _docName, type, resID];
}

- (NSString *)type
{
	return type;
}

- (void)setType:(NSString *)newType
{
	if(![type isEqualToString:newType])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeWillChangeNotification object:self];
		
		id old = type;
		type = [newType copy];
		
		// bug: this line is causing crashes!
//		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSNumber *)resID
{
	return resID;
}

- (void)setResID:(NSNumber *)newResID
{
	if(![resID isEqualToNumber:newResID])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDWillChangeNotification object:self];
		
		id old = resID;
		resID = [newResID copy];
		
		// bug: this line is causing crashes!
//		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSNumber *)attributes
{
	return attributes;
}

- (void)setAttributes:(NSNumber *)newAttributes
{
	if(![attributes isEqualToNumber:newAttributes])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesWillChangeNotification object:self];
		
		id old = attributes;
		attributes = [newAttributes copy];
		
		// bug: this line is causing crashes!
//		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

- (NSNumber *)size
{
	return @([data length]);
}

- (NSData *)data
{
	return data;
}

- (void)setData:(NSData *)newData
{
	if(![data isEqualToData:newData])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataWillChangeNotification object:self];
		
		// note: this function retains, rather than copies, the supplied data
		data = newData;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:self];
		[self setDirty:YES];
	}
}

/* encoding */

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	if (self) {
		dirty = YES;
		name = [decoder decodeObject];
		type = [decoder decodeObject];
		resID = [decoder decodeObject];
		attributes = [decoder decodeObject];
		data = [decoder decodeDataObject];
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
	return [NSString stringWithFormat:@"\n%@\nName: %@\nType: %@  ID: %@\nSize: %ld  Modified: %@", [super description], name, type, resID, (unsigned long)[data length], dirty? @"YES":@"NO"];
}

@end
