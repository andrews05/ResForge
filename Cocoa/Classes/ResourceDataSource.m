#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"

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
	[item takeValue:object forKey:identifier];
}

/* ACCESSORS */

- (Resource *)resourceNamed:(NSString *)name ofType:(NSString *)type
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

@end
