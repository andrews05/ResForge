#import "Element.h"

@implementation Element

- (id)initWithType:(NSString *)typeValue andLabel:(NSString *)labelValue
{
	// sets values directly for speed reasons (less messaging overhead)
	self = [super init];
	label = [labelValue copy];
	type = [typeValue copy];
	return self;
}

+ (id)elementOfType:(NSString *)typeValue withLabel:(NSString *)labelValue
{
	Element *element = [[Element allocWithZone:[self zone]] initWithType:typeValue andLabel:labelValue];
	return [element autorelease];
}

@end
