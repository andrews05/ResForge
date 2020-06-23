#import "DataSource.h"
#import "ResKnifeResourceProtocol.h"

@interface DataSource ()
@property (strong) NSMutableDictionary *data1;
@end

@implementation DataSource
@synthesize data1 = data;

- (instancetype)init
{
	return nil;
}

- (instancetype)initForType:(OSType)typeString
{
	self = [super init];
	if (self) {
		type = typeString;
		data = [[NSMutableDictionary alloc] init];
		NSArray *resources = [NSClassFromString(@"Resource") allResourcesOfType:type inDocument:nil];	// nil document will search in ANY open document for the correct resource
		for (id <ResKnifeResource> resource in resources )
			data[@([resource resID])] = [resource name];
		parsed = [[data allValues] mutableCopy];
	}
	return self;
}

- (NSDictionary *)data
{
	return [NSDictionary dictionaryWithDictionary:data];
}

- (void)setData:(NSMutableDictionary *)newData
{
	self.data1 = newData;
	[self parseForString:@"" sorted:YES];
}

- (void)setString:(NSString *)string forResID:(ResID)resID
{
	data[@(resID)] = string;
}

- (void)parseForString:(NSString *)string sorted:(BOOL)sort
{
	// bug: for some reason +[NSNumber isBoundedByRange:] doesn't like a range with a minimum below -30,000 (such as INT16_MIN), so I'm using INT8_MIN and screw everyone using resource IDs below that :P
	[self parseForString:string withinRange:NSMakeRange(INT8_MIN, INT16_MAX) sorted:sort];
}

- (void)parseForString:(NSString *)string withinRange:(NSRange)resIDRange sorted:(BOOL)sort
{
	NSString *trimmedString = [DataSource resNameFromStringValue:string];
	[parsed removeAllObjects];
	if( trimmedString == nil ) trimmedString = @"";
	for (NSNumber *NumID in data) {
		short resID = [NumID shortValue];
		NSString *value = data[NumID];
		NSRange range = [value rangeOfString:trimmedString options:NSCaseInsensitiveSearch];
		if( ((range.location != NSNotFound && range.length != 0) || [trimmedString isEqualToString:@""]) && NSLocationInRange(resID, resIDRange) )
			[parsed addObject:[self stringValueForResID:resID]];
	}
	
	// crap hack to allow user to change the insertion point if what they typed doesn't yet match an existing resource
	if( [parsed count] == 0 ) [parsed addObject:string];
	
	// sort case insensitive if sorting is requested
	if( sort ) [parsed sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (id)objectValueForResID:(ResID)resID
{
	return data[@(resID)];
}

- (NSString *)stringValueForResID:(ResID)resID
{
	if( resID && data[@(resID)] )
		return [NSString stringWithFormat:@"%@ {%@}", data[@(resID)], @(resID)];
	else if( resID == -1 )
		return @"";
	else if( resID )
		return [NSString stringWithFormat:@"{%@}", @(resID)];
	return nil;
}

+ (short)resIDFromStringValue:(NSString *)string
{
	NSRange span, range = NSMakeRange(0,0);
	span = [string rangeOfString:@"{" options:NSBackwardsSearch];
	if( span.location != NSNotFound )	range.location = span.location +1;
	else return -1;
	span = [string rangeOfString:@"}" options:NSBackwardsSearch];
	if( span.location != NSNotFound )	range.length = span.location - range.location;
	else return -1;
	@try {
		return [@([[string substringWithRange:range] intValue]) shortValue];
	} @catch (NSException *localException) {
		return 1;
	}
}

+ (NSString *)resNameFromStringValue:(NSString *)string
{
	NSRange range = [string rangeOfString:@"{" options:NSBackwardsSearch];
	if( range.location != NSNotFound && range.location > 0 )
		return [string substringToIndex:range.location -1];
	else if( range.location == 0 )
		return nil;
	else
		return string;
}

/* NSComboBox Informal Prototype Implementation */

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
	return parsed[index];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox
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
	return [NSString stringWithFormat:@"\nType: %@\nData: %@\nParsed Data: %@\n", GetNSStringFromOSType(type), [data description], [parsed description]];
}

@end
