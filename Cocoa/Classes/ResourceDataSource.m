#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"
@import Darwin.C.limits;

NSString *DataSourceWillAddResourceNotification = @"DataSourceWillAddResource";
NSString *DataSourceDidAddResourceNotification = @"DataSourceDidAddResource";
NSString *DataSourceWillRemoveResourceNotification = @"DataSourceWillRemoveResource";
NSString *DataSourceDidRemoveResourceNotification = @"DataSourceDidRemoveResource";

extern NSString *RKResourcePboardType;

@implementation ResourceDataSource
@synthesize document;
@synthesize outlineView;
@synthesize resourcesByType;
@synthesize allTypes;

- (instancetype)init
{
	self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeWillChange:) name:ResourceTypeWillChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeDidChange:) name:ResourceTypeDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDidChange:) name:ResourceDidChangeNotification object:nil];
    
    resourcesByType = [[NSMutableDictionary alloc] init];
    allTypes = [[NSMutableArray alloc] init];
    
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *)resources
{
    return [[resourcesByType allValues] valueForKeyPath:@"@unionOfArrays.self"];
}

- (void)addResources:(NSArray<Resource*> *)resources
{
	for( Resource* res in resources )
	{
		[self addResourceToTypedList: res];
	}
    
    // Default sort resources by id
    if ( [[outlineView sortDescriptors] count] == 0 ) {
        [outlineView setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"resID" ascending:YES]]];
    } else {
        [self outlineView:outlineView sortDescriptorsDidChange:[outlineView sortDescriptors]];
    }
}

- (void)addResource:(Resource *)resource
{
	NSDictionary *dictionary = @{@"DataSource": self, @"Resource": resource};
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceWillAddResourceNotification object:dictionary];
	
	// it seems very inefficient to reload the entire data source when just adding/removing one item
	//	for large resource files, the data source gets reloaded hundreds of times upon load
	[self addResourceToTypedList: resource];
    [resource setDocument:document];
    [resourcesByType[@(resource.type)] sortUsingDescriptors:[outlineView sortDescriptors]];
	[outlineView reloadData];
    [outlineView expandItem:@(resource.type)];

	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceDidAddResourceNotification object:dictionary];
	[[document undoManager] registerUndoWithTarget:self selector:@selector(removeResource:) object:resource];	// undo action name set by calling function
}

- (void)removeResource:(Resource *)resource
{
	NSDictionary *dictionary = @{@"DataSource": self, @"Resource": resource};
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceWillRemoveResourceNotification object:dictionary];
	
	// see comments in addResource: about inefficiency of reloadData
	[self removeResourceFromTypedList: resource];
	[outlineView reloadData];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceDidRemoveResourceNotification object:dictionary];
	[[document undoManager] registerUndoWithTarget:self selector:@selector(addResource:) object:resource];	// NB: I hope the undo manager retains the resource, because it just got deleted :)  -  undo action name set by calling function
}

-(void)addResourceToTypedList:(Resource*)inResource
{
    NSMutableArray* listsForType = resourcesByType[@(inResource.type)];
    if( !listsForType )
    {
        listsForType = [NSMutableArray arrayWithObject: inResource];
        resourcesByType[@(inResource.type)] = listsForType;
        [allTypes addObject:GetNSStringFromOSType(inResource.type)];
        [allTypes sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    else
    {
        [listsForType addObject: inResource];
    }
}

-(void)removeResourceFromTypedList:(Resource*)inResource
{
    NSMutableArray* listsForType = resourcesByType[@(inResource.type)];
    [listsForType removeObject: inResource];
    if ([listsForType count] == 0) {
        [resourcesByType removeObjectForKey:@(inResource.type)];
        [allTypes removeObject:GetNSStringFromOSType(inResource.type)];
    }
}

- (void)resourceTypeWillChange:(NSNotification *)notification
{
    Resource* resource = [notification object];
    if ([resource document] == document)
        [self removeResourceFromTypedList:resource];
}

- (void)resourceTypeDidChange:(NSNotification *)notification
{
    Resource* resource = [notification object];
    if ([resource document] == document) {
        [self addResourceToTypedList:resource];
        [resourcesByType[@(resource.type)] sortUsingDescriptors:[outlineView sortDescriptors]];
        [outlineView reloadData];
        [self selectResources:@[resource]];
    }
}

- (void)resourceDidChange:(NSNotification *)notification
{
	// reload the data for the changed resource
	[outlineView reloadItem:[notification object]];
}

- (NSArray *)allResourcesForItems:(NSArray *)items
{
    if (!items.count) return items;
    NSMutableArray *resources = [[NSMutableArray alloc] init];
    // loop through items and add all child resources
    for (id item in items) {
        if ([outlineView isExpandable:item]) {
            for (int i = 0; i < [outlineView numberOfChildrenOfItem:item]; i++) {
                [resources addObject:[outlineView child:i ofItem:item]];
            }
        } else if (![resources containsObject:item]) {
            [resources addObject:item];
        }
    }
    return resources;
}

- (void)selectResources:(NSArray *)resources
{
    NSMutableIndexSet* indexes = [[NSMutableIndexSet alloc] init];
    for (Resource* resource in resources) {
        [outlineView expandItem:@(resource.type)];
        [indexes addIndex:[outlineView rowForItem:resource]];
    }
    [outlineView selectRowIndexes:indexes byExtendingSelection:NO];
}

/* Data source protocol implementation */

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	#pragma unused(outlineView)
    if( item == nil ) {
		NSNumber* resType = @(GetOSTypeFromNSString([allTypes objectAtIndex: index]));
        if ( [resType isEqual:@0] )
            return [resourcesByType[resType] objectAtIndex:0];
        else
            return resType;
    }
    else
		return [resourcesByType[item] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	#pragma unused(outlineView)
	return( ![item isKindOfClass: [Resource class]] );
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	#pragma unused(outlineView, item)
	if( item == nil )
		return resourcesByType.allKeys.count;
	else if( [item isKindOfClass: [Resource class]] )
		return 0;
	else
		return resourcesByType[item].count;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused(outlineView)
	if( [item isKindOfClass: [Resource class]] )
		return [item valueForKey:[tableColumn identifier]];
	else if( [tableColumn.identifier isEqualToString: @"name"] )
		return GetNSStringFromOSType([item intValue]);
    else if( [tableColumn.identifier isEqualToString: @"size"] )
        return @(resourcesByType[item].count);
	else
		return @"";
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused(outlineView)
	if( [item isKindOfClass: [Resource class]] )
	{
		NSString *identifier = [tableColumn identifier];
		if([identifier isEqualToString:@"resID"])
			[item setValue:@([object intValue]) forKey:identifier];
		else [item setValue:object forKey:identifier];
	}
}

#pragma mark -
/* ACCESSORS */

- (Resource *)resourceOfType:(OSType)type andID:(short)resID
{
	for (Resource *resource in resourcesByType[@(type)]) {
		if(resID && resource.resID == resID && type && resource.type == type)
			return resource;
	}
	return nil;
}

- (Resource *)resourceOfType:(OSType)type withName:(NSString *)name
{
	for (Resource *resource in resourcesByType[@(type)]) {
		if([resource.name isEqualToString:name] && resource.type == type)
			return resource;
	}
	return nil;
}

- (NSArray *)allResourcesOfType:(OSType)type
{
	return [NSArray arrayWithArray:resourcesByType[@(type)]];
}

/*!
@method		allResourceIDsOfType:
@discussion	Returns an NSArray full of NSNumber* objects containing the IDs of all resources of specified type. Used by uniqueIDForType:.
@updated	2003-08-01  UK  Created based on allResourcesOfType:
*/

- (NSArray*)allResourceIDsOfType:(OSType)type
{
	if(!type)
		return @[];
	
	NSMutableArray  *array = [NSMutableArray array];
	for (Resource *resource in resourcesByType[@(type)]) {
		if([resource type] == type)
			[array addObject:@(resource.resID)];
	}
	return [NSArray arrayWithArray:array];
}

/*!
@method		uniqueIDForType:
@discussion	Tries to return an unused resource ID for a new resource of specified type. If all IDs are used up (can't really happen, because the resource manager can't take more than 2727 resources per file without crashing, but just in theory...), this will return 128 no matter whether it's used or not.
@updated	2003-08-01  UK:  Created.
@updated	2003-10-21  NGS:  Changed to obtain initial ID from -[resource defaultIDForType:], so we can vary it on a pre-resource-type basis (like Resourcerer can)
*/

- (short)uniqueIDForType:(OSType)type
{
	short   theID = [self defaultIDForType:type];
	NSArray *array = [self allResourceIDsOfType:type];
	
	if([array count] <= USHRT_MAX)
	{
		while([array containsObject:@(theID)])
			theID++;
	}
	
	return theID;
}

/*!
@method		defaultIDForType:
@pending	Method should look for resources specifying what the initial ID is for this resource type (e.g. 'vers' resources start at 0)
*/

- (short)defaultIDForType:(OSType)type
{
	short defaultID = 128;
	return defaultID;
}

#pragma mark -

/*!
@method		outlineView:writeItems:toPasteboard:
@abstract   Called at the start of a drag event.
*/
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	[pb declareTypes:@[RKResourcePboardType] owner:self];
    
    [pb setData:[NSKeyedArchiver archivedDataWithRootObject:[self allResourcesForItems:items]] forType:RKResourcePboardType];
	return YES;
}

/*!
@method		outlineView:validateDrop:proposedItem:proposedChildIndex:
@abstract   Called when the user is hovering with a drop over our outline view.
*/
- (NSDragOperation)outlineView:(NSOutlineView *)oView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)childIndex
{
	if([info draggingSource] != oView)
	{
		[oView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex];
		return NSDragOperationCopy;
	}
	else return NSDragOperationNone;
}

/*!
@method		outlineView:acceptDrop:item:childIndex:
@abstract   Called when the user drops something on our outline view.
*/
- (BOOL)outlineView:(NSOutlineView *)oView acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(NSInteger)childIndex
{
	NSPasteboard *pb = [info draggingPasteboard];
	if([pb availableTypeFromArray:@[RKResourcePboardType]])
		[document pasteResources:[NSKeyedUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
	return YES;
}

- (void)outlineView:(NSOutlineView *)oView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    for (NSNumber* key in resourcesByType) {
        [[resourcesByType objectForKey:key] sortUsingDescriptors:[outlineView sortDescriptors]];
    }
    [outlineView reloadData];
}

@end
