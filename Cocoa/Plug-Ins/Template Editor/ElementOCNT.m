#import "ElementOCNT.h"

// implements ZCNT, OCNT, BCNT, BZCT, WCNT, WZCT, LCNT, LZCT
@implementation ElementOCNT
@synthesize value;
@synthesize entries;
@dynamic stringValue;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        entries = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ElementOCNT *element = [super copyWithZone:zone];
	if(!element) return nil;
	
	// always reset counter on copy
	element.value = 0;
    [element.entries removeAllObjects];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	value = 0;
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		[stream readAmount:4 toBuffer:&value];
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		[stream readAmount:1 toBuffer:(char *)(&value)+3];
	else
		[stream readAmount:2 toBuffer:(short *)(&value)+1];
	
	value = CFSwapInt32BigToHost(value);
	if ([self countFromZero])
		value += 1;
}

- (unsigned int)sizeOnDisk
{
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		return 4;
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		return 1;
	else
		return 2;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	if ([self countFromZero])
		value -= 1;
	UInt32 tmp = CFSwapInt32HostToBig(value);
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		[stream writeAmount:4 fromBuffer:&tmp];
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		[stream writeAmount:1 fromBuffer:(char *)(&tmp)+3];
	else
		[stream writeAmount:2 fromBuffer:(short *)(&tmp)+1];
	if ([self countFromZero])
		value += 1;
}

- (BOOL)countFromZero
{
	return [self.type isEqualToString:@"ZCNT"] ||
	       [self.type isEqualToString:@"BZCT"] ||
		   [self.type isEqualToString:@"WZCT"] ||
		   [self.type isEqualToString:@"LZCT"];
}

- (void)addEntry:(Element *)entry after:(Element *)after
{
    if (after == nil) {
        [entries addObject:entry];
    } else {
        [entries insertObject:entry atIndex:[entries indexOfObject:after]];
    }
    value++;
}

- (void)removeEntry:(Element *)entry
{
    [entries removeObject:entry];
    value--;
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%ld", (unsigned long)value];
}

- (void)setStringValue:(NSString *)str
{
}

- (BOOL)editable
{
	return NO;
}

@end

