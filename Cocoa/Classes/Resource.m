#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"

NSString *RKResourcePboardType = @"RKResourcePboardType";

#define kRSRCName @"ResourceName"
#define kRSRCData @"ResourceData"
#define kRSRCID @"ResourceID"
#define kRSRCType @"ResourceType"
#define kRSRCAttrib @"ResourceAttribute"

@interface Resource ()
@property (copy) NSString *_name;
@property (copy) NSData *_data;
@end

@implementation Resource
@synthesize _name = name;
@synthesize dirty;
@synthesize _data = data;
@synthesize representedFork;
@synthesize attributes;
@synthesize type;
@dynamic name;
@dynamic data;
@synthesize document;
static ResourceDataSource* supportDataSource;

- (instancetype)init
{
	return self = [self initWithType:'NULL' andID:128 withName:@"" andAttributes:0 data:[NSData data]];
}

- (instancetype)initWithType:(OSType)typeValue andID:(short)resIDValue
{
	return self = [self initWithType:typeValue andID:resIDValue withName:@"" andAttributes:0 data:[NSData data]];
}

- (instancetype)initWithType:(OSType)typeValue andID:(short)resIDValue withName:(NSString *)nameValue andAttributes:(UInt16)attributesValue
{
	return [self initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:[NSData data]];
}

- (instancetype)initWithType:(OSType)typeValue andID:(short)resIDValue withName:(NSString *)nameValue andAttributes:(UInt16)attributesValue data:(NSData *)dataValue
{
	// sets values directly for speed reasons (less messaging overhead)
	if (self = [super init]) {
		dirty = NO;
		representedFork = nil;
		self._name = nameValue;
		type = typeValue;
		resID = resIDValue;
		attributes = attributesValue;
		self._data = dataValue;
	}
	return self;
}


+ (id)resourceOfType:(OSType)typeValue andID:(short)resIDValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue];
	return resource;
}

+ (id)resourceOfType:(OSType)typeValue andID:(short)resIDValue withName:(NSString *)nameValue andAttributes:(UInt16)attributesValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue];
	return resource;
}

+ (id)resourceOfType:(OSType)typeValue andID:(short)resIDValue withName:(NSString *)nameValue andAttributes:(UInt16)attributesValue data:(NSData *)dataValue
{
	Resource *resource = [[Resource allocWithZone:nil] initWithType:typeValue andID:resIDValue withName:nameValue andAttributes:attributesValue data:dataValue];
	return resource;
}

+ (Resource *)getResourceOfType:(OSType)typeValue andID:(short)resIDValue inDocument:(NSDocument *)searchDoc
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
    Resource *resource = [supportDataSource resourceOfType:typeValue andID:resIDValue];
    if(resource) return resource;
	return nil;
}

/* ResKnifeResource implementation */
+ (NSArray *)allResourcesOfType:(OSType)typeValue inDocument:(NSDocument *)searchDoc
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

+ (Resource *)resourceOfType:(OSType)typeValue withName:(NSString *)nameValue inDocument:(NSDocument *)searchDoc
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
    Resource *resource = [supportDataSource resourceOfType:typeValue withName:nameValue];
    if(resource) return resource;
	return nil;
}

+ (Resource *)resourceOfType:(OSType)typeValue andID:(short)resIDValue inDocument:(NSDocument *)searchDoc
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
    Resource *resource = [supportDataSource resourceOfType:typeValue andID:resIDValue];
    if(resource) return resource;
	return nil;
}

+ (ResourceDataSource *)supportDataSource
{
    if (!supportDataSource) {
        supportDataSource = [[ResourceDataSource alloc] init];
    }
    return supportDataSource;
}

- (id)copyWithZone:(NSZone *)zone
{
	Resource *copy = [[Resource alloc] initWithType:type andID:resID withName:name andAttributes:attributes data:[data copy]];
	[copy setDocument:document];
	return copy;
}

/* accessors */

- (void)touch
{
	self.dirty = YES;
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

- (NSString *)name
{
	return name;
}

// shouldn't need this - it's used by forks to give them alternate names - should use name formatter replacement instead
- (void)_setName:(NSString *)newName
{
	self._name = newName;
}

- (void)setName:(NSString *)newName
{
	if(![name isEqualToString:newName])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameWillChangeNotification object:self];
		
		self._name = newName;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceNameDidChangeNotification object:self];
		self.dirty = YES;
	}
}

- (NSString *)defaultWindowTitle
{
	if([name length] > 0)	return [NSString stringWithFormat: NSLocalizedString(@"%@: %@ %i '%@'", @"default window title format with resource name"), [document displayName], GetNSStringFromOSType(type), resID, name];
	else					return [NSString stringWithFormat: NSLocalizedString(@"%@: %@ %i", @"default window title format without resource name"), [document displayName], GetNSStringFromOSType(type), resID];
}

- (OSType)type
{
	return type;
}

- (void)setType:(OSType)newType
{
	if(type != newType)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeWillChangeNotification object:self];
		
		type = newType;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceTypeDidChangeNotification object:self];
		self.dirty = YES;
	}
}

@synthesize resID;
- (short)resID
{
	return resID;
}

- (void)setResID:(short)newResID
{
	if(resID != newResID)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDWillChangeNotification object:self];
		
		resID = newResID;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceIDDidChangeNotification object:self];
		self.dirty = YES;
	}
}

- (RKResAttribute)attributes
{
	return attributes;
}

- (void)setAttributes:(RKResAttribute)newAttributes
{
	if(attributes != newAttributes)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceWillChangeNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesWillChangeNotification object:self];
		
		attributes = newAttributes;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceAttributesDidChangeNotification object:self];
		self.dirty = YES;
	}
}

- (NSUInteger)size
{
	return [data length];
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
		self._data = newData;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:self];
		self.dirty = YES;
	}
}

/* encoding */

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	if (self) {
		dirty = YES;
		if ([decoder allowsKeyedCoding]) {
			self._name = [decoder decodeObjectForKey:kRSRCName];
			type = [decoder decodeInt32ForKey:kRSRCType];
			resID = (short)[decoder decodeInt32ForKey:kRSRCID];
			attributes = (UInt16)[decoder decodeInt32ForKey:kRSRCAttrib];
			self._data = [decoder decodeObjectForKey:kRSRCData];
		} else {
			self._name = [decoder decodeObject];
			type = [(NSNumber*)[decoder decodeObject] unsignedIntValue];
			resID = [(NSNumber*)[decoder decodeObject] shortValue];
			attributes = [(NSNumber*)[decoder decodeObject] unsignedShortValue];
			self._data = [decoder decodeDataObject];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	NSAssert([encoder allowsKeyedCoding], @"Keyed Coding is not available");
	[encoder encodeObject:name forKey:kRSRCName];
	[encoder encodeInt32:resID forKey:kRSRCID];
	[encoder encodeInt32:attributes forKey:kRSRCAttrib];
	[encoder encodeInt32:type forKey:kRSRCType];
	[encoder encodeObject:data forKey:kRSRCData];
}

/* description */

- (NSString *)description
{
	return [NSString stringWithFormat:@"\n%@\nName: %@\nType: %@  ID: %hd\nSize: %ld  Modified: %@", [super description], name, GetNSStringFromOSType(type), resID, (unsigned long)[data length], dirty? @"YES":@"NO"];
}

@end
