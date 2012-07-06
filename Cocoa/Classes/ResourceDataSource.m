#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"
#import <limits.h>

NSString *DataSourceWillAddResourceNotification = @"DataSourceWillAddResource";
NSString *DataSourceDidAddResourceNotification = @"DataSourceDidAddResource";
NSString *DataSourceWillRemoveResourceNotification = @"DataSourceWillRemoveResource";
NSString *DataSourceDidRemoveResourceNotification = @"DataSourceDidRemoveResource";

extern NSString *RKResourcePboardType;

@implementation ResourceDataSource

- (id)init
{
	self = [super init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDidChange:) name:ResourceDidChangeNotification object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (NSWindow *)window
{
	return window;
}

- (NSArray *)resources
{
	return resources;
}

- (void)setResources:(NSMutableArray *)newResources
{
	id old = resources;
	resources = [newResources retain];
	[old release];
	[resources sortUsingDescriptors:[outlineView sortDescriptors]];
	[outlineView reloadData];
}

- (void)addResource:(Resource *)resource
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:self, @"DataSource", resource, @"Resource", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceWillAddResourceNotification object:dictionary];
	
	// it seems very inefficient to reload the entire data source when just adding/removing one item
	//	for large resource files, the data source gets reloaded hundreds of times upon load
	[resources addObject:resource];
	[outlineView reloadData];

	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceDidAddResourceNotification object:dictionary];
	[[document undoManager] registerUndoWithTarget:self selector:@selector(removeResource:) object:resource];	// undo action name set by calling function
}

- (void)removeResource:(Resource *)resource
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:self, @"DataSource", resource, @"Resource", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceWillRemoveResourceNotification object:dictionary];
	
	// see comments in addResource: about inefficiency of reloadData
	[resources removeObjectIdenticalTo:resource];
	[outlineView reloadData];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceDidRemoveResourceNotification object:dictionary];
	[[document undoManager] registerUndoWithTarget:self selector:@selector(addResource:) object:resource];	// NB: I hope the undo manager retains the resource, because it just got deleted :)  -  undo action name set by calling function
}

- (void)resourceDidChange:(NSNotification *)notification
{
	// reload the data for the changed resource
	[outlineView reloadItem:[notification object]];
}

/* Data source protocol implementation */

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	#pragma unused(outlineView, item)
	return [resources objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	#pragma unused(outlineView, item)
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	#pragma unused(outlineView, item)
	return [resources count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused(outlineView)
	return [item valueForKey:[tableColumn identifier]];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused(outlineView)
	NSString *identifier = [tableColumn identifier];
	if([identifier isEqualToString:@"resID"])
		[item setValue:[NSNumber numberWithInt:[object intValue]] forKey:identifier];
	else [item setValue:object forKey:identifier];
}

#pragma mark -
/* ACCESSORS */

- (Resource *)resourceOfType:(NSString *)type andID:(NSNumber *)resID
{
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		if(resID && [[resource resID] isEqualToNumber:resID] && type && [[resource type] isEqualToString:type])
			return resource;
	}
	return nil;
}

- (Resource *)resourceOfType:(NSString *)type withName:(NSString *)name
{
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		if([[resource name] isEqualToString:name] && [[resource type] isEqualToString:type])
			return resource;
	}
	return nil;
}

- (NSArray *)allResourcesOfType:(NSString *)type
{
	Resource		*resource;
	NSMutableArray  *array = [NSMutableArray array];
	NSEnumerator	*enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		if([[resource type] isEqualToString:type])
			[array addObject:resource];
	}
	return [NSArray arrayWithArray:array];
}

/*!
@method		allResourceIDsOfType:
@discussion	Returns an NSArray full of NSNumber* objects containing the IDs of all resources of specified type. Used by uniqueIDForType:.
@updated	2003-08-01  UK  Created based on allResourcesOfType:
*/

- (NSArray*)allResourceIDsOfType:(NSString *)type
{
	if(!type || [type isEqualToString:@""])
		return [NSArray array];
	
	Resource		*resource;
	NSMutableArray  *array = [NSMutableArray array];
	NSEnumerator	*enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		if([[resource type] isEqualToString:type])
			[array addObject:[resource resID]];
	}
	return [NSArray arrayWithArray:array];
}

/*!
@method		uniqueIDForType:
@discussion	Tries to return an unused resource ID for a new resource of specified type. If all IDs are used up (can't really happen, because the resource manager can't take more than 2727 resources per file without crashing, but just in theory...), this will return 128 no matter whether it's used or not.
@updated	2003-08-01  UK:  Created.
@updated	2003-10-21  NGS:  Changed to obtain initial ID from -[resource defaultIDForType:], so we can vary it on a pre-resource-type basis (like Resourcerer can)
*/

- (NSNumber *)uniqueIDForType:(NSString *)type
{
	short   theID = [[self defaultIDForType:type] shortValue];
	NSArray *array = [self allResourceIDsOfType:type];
	
	if([array count] <= USHRT_MAX)
	{
		while([array containsObject:[NSNumber numberWithShort:theID]])
			theID++;
	}
	
	return [NSNumber numberWithShort: theID];
}

/*!
@method		defaultIDForType:
@pending	Method should look for resources specifying what the initial ID is for this resource type (e.g. 'vers' resources start at 0)
*/

- (NSNumber *)defaultIDForType:(NSString *)type
{
	short defaultID = 128;
	return [NSNumber numberWithShort:defaultID];
}

#pragma mark -

/*!
@method		outlineView:writeItems:toPasteboard:
@abstract   Called at the start of a drag event.
*/
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pb
{
	[pb declareTypes:[NSArray arrayWithObject:RKResourcePboardType] owner:self];
	[pb setData:[NSArchiver archivedDataWithRootObject:items] forType:RKResourcePboardType];
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
	if([pb availableTypeFromArray:[NSArray arrayWithObject:RKResourcePboardType]])
		[document pasteResources:[NSUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
	return YES;
}

- (void)outlineView:(NSOutlineView *)oView sortDescriptorsDidChange:(NSArray *)oldDescriptors {	
	[resources sortUsingDescriptors:[oView sortDescriptors]];
	[oView reloadData];
}


@end
