#import "DataSource.h"
#import "ResKnifeResourceProtocol.h"

@implementation DataSource

- (id)init
{
	[self autorelease];
	return nil;
}

- (id)initForType:(NSString *)typeString
{
	self = [super init];
	type = [typeString copy];
	data = [[NSMutableDictionary alloc] init];
	{
		id <ResKnifeResourceProtocol> resource;
		NSArray *resources = [NSClassFromString(@"Resource") allResourcesOfType:type inDocument:nil];
		NSEnumerator *enumerator = [resources objectEnumerator];
		while( resource = [enumerator nextObject] )
			[data setObject:[resource name] forKey:[resource resID]];
	}
	parsed = [[NSMutableArray alloc] initWithArray:[data allValues]];
	return self;
}

- (void)dealloc
{
	[data release];
	[parsed release];
	[super dealloc];
}

- (NSDictionary *)data
{
	return data;
}

- (void)setData:(NSMutableDictionary *)newData
{
	id old = data;
	data = [newData retain];
	[self parseForString:@"" sorted:YES];
	[old autorelease];
}

- (void)setString:(NSString *)string forResID:(int)resID
{
	[data setObject:string forKey:[NSNumber numberWithInt:resID]];
}

- (void)parseForString:(NSString *)string sorted:(BOOL)sort
{
	NSNumber *resID;
	NSEnumerator *enumerator = [[data allKeys] objectEnumerator];
	[parsed removeAllObjects];
	while( resID = [enumerator nextObject] )
	{
		NSString *value = [data objectForKey:resID];
		NSRange range = [value rangeOfString:string options:NSCaseInsensitiveSearch];
		if( range.location != NSNotFound || [string isEqualToString:@""] )
			[parsed addObject:[NSString stringWithFormat:@"%@ {%@}", value, resID]];
	}
	if( sort ) [parsed sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (id)objectValueForResID:(NSNumber *)resID
{
	return [data objectForKey:resID];
}

- (NSString *)stringValueForResID:(NSNumber *)resID
{
	return [NSString stringWithFormat:@"%@ {%@}", [data objectForKey:resID], resID];
}

/* NSComboBox Informal Prototype Implementation */

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(int)index
{
	return [parsed objectAtIndex:index];
}

- (int)numberOfItemsInComboBox:(NSComboBox *)comboBox
{
	return [parsed count];
}

/* Combo Box Delegate Methods */

- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
	[self parseForString:[[notification object] stringValue] sorted:YES];
	[[notification object] reloadData];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self parseForString:[[notification object] stringValue] sorted:YES];
	[[notification object] reloadData];
}

- (BOOL)control:(NSControl *)control isValidObject:(id)object
{
	return [parsed containsObject:object];
}

@end
