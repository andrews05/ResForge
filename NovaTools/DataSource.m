#import "DataSource.h"
#import "ResKnifeResourceProtocol.h"
#import "NSNumber-Range.h"

@implementation DataSource

- (id)init
{
	[self autorelease];
	return nil;
}

- (id)initForType:(NSString *)typeString
{
	self = [super init];
	if (self) {
		type = [typeString copy];
		data = [[NSMutableDictionary alloc] init];
		NSArray *resources = [NSClassFromString(@"Resource") allResourcesOfType:type inDocument:nil];	// nil document will search in ANY open document for the correct resource
		NSEnumerator *enumerator = [resources objectEnumerator];
		while( id <ResKnifeResourceProtocol> resource in resources )
			[data setObject:[resource name] forKey:[resource resID]];
	}
	parsed = [[NSMutableArray alloc] initWithArray:[data allValues]];
	return self;
}

- (void)dealloc
{
	[type release];
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
	// bug: for some reason +[NSNumber isBoundedByRange:] doesn't like a range with a minimum below -30,000 (such as INT16_MIN), so I'm using INT8_MIN and screw everyone using resource IDs below that :P
	[self parseForString:string withinRange:NSMakeRange(INT8_MIN, INT16_MAX) sorted:sort];
}

- (void)parseForString:(NSString *)string withinRange:(NSRange)resIDRange sorted:(BOOL)sort
{
	NSNumber *resID;
	NSString *trimmedString = [DataSource resNameFromStringValue:string];
	NSEnumerator *enumerator = [[data allKeys] objectEnumerator];
	[parsed removeAllObjects];
	if( trimmedString == nil ) trimmedString = @"";
	while( resID = [enumerator nextObject] )
	{
		NSString *value = [data objectForKey:resID];
		NSRange range = [value rangeOfString:trimmedString options:NSCaseInsensitiveSearch];
		if( ((range.location != NSNotFound && range.length != 0) || [trimmedString isEqualToString:@""]) && [resID isBoundedByRange:resIDRange] )
			[parsed addObject:[self stringValueForResID:resID]];
	}
	
	// crap hack to allow user to change the insertion point if what they typed doesn't yet match an existing resource
	if( [parsed count] == 0 ) [parsed addObject:string];
	
	// sort case insensitive if sorting is requested
	if( sort ) [parsed sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (id)objectValueForResID:(NSNumber *)resID
{
	return [data objectForKey:resID];
}

- (NSString *)stringValueForResID:(NSNumber *)resID
{
	if( resID && [data objectForKey:resID] )
		return [NSString stringWithFormat:@"%@ {%@}", [data objectForKey:resID], resID];
	else if( [resID shortValue] == -1 )
		return @"";
	else if( resID )
		return [NSString stringWithFormat:@"{%@}", resID];
	return nil;
}

+ (NSNumber *)resIDFromStringValue:(NSString *)string
{
	NSRange span, range = NSMakeRange(0,0);
	span = [string rangeOfString:@"{" options:NSBackwardsSearch];
	if( span.location != NSNotFound )	range.location = span.location +1;
	else return [NSNumber numberWithInt:-1];
	span = [string rangeOfString:@"}" options:NSBackwardsSearch];
	if( span.location != NSNotFound )	range.length = span.location - range.location;
	else return [NSNumber numberWithInt:-1];
	NS_DURING
		NS_VALUERETURN( [[[NSNumber alloc] initWithInt:[[string substringWithRange:range] intValue]] autorelease], NSNumber* );
	NS_HANDLER
		NS_VALUERETURN( [NSNumber numberWithInt:-1], NSNumber* );
	NS_ENDHANDLER
}

+ (NSString *)resNameFromStringValue:(NSString *)string
{
	NSRange range = [string rangeOfString:@"{" options:NSBackwardsSearch];
	if( range.location != NSNotFound && range.location > 0 )
		return [string substringToIndex:range.location -1];
	else if( range.location == 0 )
		return nil;
	else return string;
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

- (BOOL)control:(NSControl *)control isValidObject:(id)object
{
	return [parsed containsObject:object];
}

/* Description */

- (NSString *)description
{
	return [NSString stringWithFormat:@"\nType: %@\nData: %@\nParsed Data: %@\n", type, [data description], [parsed description]];
}

@end
