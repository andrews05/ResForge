/* =============================================================================
	PROJECT:	ResKnife
	FILE:		ResourceDataSource.m
	
	PURPOSE:
		Dedicated data source for our resource list. Shares its list of
		resources with ResourceDocument. I have no idea why Nick did this
		split, though...
	
	AUTHORS:	Nick Shanks, nick(at)nickshanks.com, (c) ~2001.
				M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Added storing document pointer in resource, commented.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"
#import <limits.h>


/* -----------------------------------------------------------------------------
	Notification names:
   -------------------------------------------------------------------------- */

NSString *DataSourceWillAddResourceNotification = @"DataSourceWillAddResourceNotification";
NSString *DataSourceDidAddResourceNotification = @"DataSourceDidAddResourceNotification";
NSString *DataSourceWillRemoveResourceNotification = @"DataSourceWillRemoveResourceNotification";
NSString *DataSourceDidRemoveResourceNotification = @"DataSourceDidRemoveResourceNotification";

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
	[resources autorelease];
	resources = [newResources retain];
	[outlineView reloadData];
}

- (void)addResource:(Resource *)resource
{
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:self, @"DataSource", resource, @"Resource", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:DataSourceWillAddResourceNotification object:dictionary];
	
	// it seems very inefficient to reload the entire data source when just adding/removing one item
	//	for large resource files, the data source gets reloaded hundereds of times upon load
	[resource setDocument:document];
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


/* -----------------------------------------------------------------------------
	resourceDidChange:
		Notification from the Resource class that we're registered to. It's
		sent whenever the resource is "touch"ed.
	
	REVISIONS:
		2003-08-01  UK  Commented, made this "touch" the document as well.
   -------------------------------------------------------------------------- */

-(void) resourceDidChange: (NSNotification*)notification
{
	// reload the data for the changed resource
	[outlineView reloadItem:[notification object]];
	[document updateChangeCount: NSChangeDone];		// TODO: We shouldn't need to do this, Undo should take care of this, according to the docs, but somehow the document always forgets its changes.
}

/* Data source protocol implementation */

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	#pragma unused( outlineView, item )
	return [resources objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	#pragma unused( outlineView, item )
	return NO;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	#pragma unused( outlineView, item )
	return [resources count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused( outlineView )
	return [item valueForKey:[tableColumn identifier]];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	#pragma unused( outlineView )
	NSString *identifier = [tableColumn identifier];
	if( [identifier isEqualToString:@"resID"] )
		[item takeValue:[NSNumber numberWithInt:[object intValue]] forKey:identifier];
	else [item takeValue:object forKey:identifier];
}

/* ACCESSORS */

- (Resource *)resourceOfType:(NSString *)type andID:(NSNumber *)resID
{
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while( resource = [enumerator nextObject] )
	{
		if( resID && [[resource resID] isEqualToNumber:resID] && type && [[resource type] isEqualToString:type] )
			return resource;
	}
	return nil;
}

- (Resource *)resourceOfType:(NSString *)type withName:(NSString *)name
{
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while( resource = [enumerator nextObject] )
	{
		if( [[resource name] isEqualToString:name] && [[resource type] isEqualToString:type] )
			return resource;
	}
	return nil;
}

- (NSArray *)allResourcesOfType:(NSString *)type
{
	Resource *resource;
	NSMutableArray *array = [NSMutableArray array];
	NSEnumerator *enumerator = [resources objectEnumerator];
	while( resource = [enumerator nextObject] )
	{
		if( [[resource type] isEqualToString:type] )
			[array addObject:resource];
	}
	return [NSArray arrayWithArray:array];
}


/* -----------------------------------------------------------------------------
	allResourceIDsOfType:
		Returns an NSArray full of NSNumber* objects containing the IDs of all
		resources of specified type. Used by uniqueIDForType:.
	
	REVISIONS:
		2003-08-01  UK  Created based on allResourcesOfType:.
   -------------------------------------------------------------------------- */

-(NSArray*) allResourceIDsOfType: (NSString*)type
{
	Resource		*resource;
	NSMutableArray  *array = [NSMutableArray array];
	NSEnumerator	*enumerator = [resources objectEnumerator];
	while( resource = [enumerator nextObject] )
	{
		if( [[resource type] isEqualToString:type] )
			[array addObject:[resource resID]];
	}
	return [NSArray arrayWithArray:array];
}


/* -----------------------------------------------------------------------------
	uniqueIDForType:
		Tries to return an unused resource ID for a new resource of specified
		type. If all IDs are used up (can't really happen, because the resource
		manager can't take more than 2727 resources per file without crashing,
		but just in theory...), this will return 128 no matter whether it's
		used or not.
	
	REVISIONS:
		2003-08-01  UK  Created.
   -------------------------------------------------------------------------- */

-(NSNumber*)	uniqueIDForType: (NSString*)type
{
	short		theID = 128;
	NSArray		*array = [self allResourceIDsOfType: type];
	
	if( [array count] <= USHRT_MAX )
	{
		while( [array containsObject: [NSNumber numberWithShort:theID]] )
			theID++;
	}
	
	return [NSNumber numberWithShort: theID];
}

@end
