#import "ResourceDataSource.h"

@implementation ResourceDataSource

- (id)init
{
	self = [super init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDidChange:) name:ResourceChangedNotification object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (CreateResourceSheetController *)createResourceSheetController
{
	return createResourceSheetController;
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
	[resources addObject:resource];
	[outlineView reloadData];
//	[outlineView noteNumberOfRowsChanged];	// what is this for if it doesn't update the damn outliine view!
}

- (void)resourceDidChange:(NSNotification *)notification
{
	[outlineView reloadData];
}

- (void)generateTestData
{
	[self addResource:[Resource resourceOfType:@"____" andID:[NSNumber numberWithShort:-1] withName:@"underscore" andAttributes:[NSNumber numberWithUnsignedShort:0x8080]]];
	[self addResource:[Resource resourceOfType:@"ÐÐÐÐ" andID:[NSNumber numberWithShort:0] withName:@"hyphen" andAttributes:[NSNumber numberWithUnsignedShort:0xFFFF] data:[NSData data] ofLength:[NSNumber numberWithUnsignedLong:1023]]];
	[self addResource:[Resource resourceOfType:@"----" andID:[NSNumber numberWithShort:128] withName:@"minus" andAttributes:[NSNumber numberWithUnsignedShort:0xABCD] data:[NSData data] ofLength:[NSNumber numberWithUnsignedLong:12000]]];
	[self addResource:[Resource resourceOfType:@"ÑÑÑÑ" andID:[NSNumber numberWithShort:32000] withName:@"en-dash" andAttributes:[NSNumber numberWithUnsignedShort:0x1234] data:[NSData data] ofLength:[NSNumber numberWithUnsignedLong:4096]]];
	[self addResource:[Resource resourceOfType:@"****" andID:[NSNumber numberWithShort:-32000]]];
}

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
	NSString *identifier = [tableColumn identifier];
	[item takeValue:object forKey:identifier];
}

@end
