#import "ElementOCNT.h"
#import "ElementLSTB.h"

// implements ZCNT, OCNT, BCNT, BZCT, WCNT, WZCT, LCNT, LZCT
@implementation ElementOCNT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.rowHeight = 17;
    }
    return self;
}

- (void)configureGroupView:(NSTableCellView *)view
{
    // Element will show as a group row - we need to combine the counter into the label
    [view.textField bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self}];
}

- (id)transformedValue:(id)value
{
    return [NSString stringWithFormat:@"%@ = %d", self.displayLabel, self.value];
}

- (void)configure
{
    ElementLSTB *lstc = (ElementLSTB *)[self.parentList nextOfType:@"LSTC"];
    if (!lstc) {
        NSLog(@"'LSTC' for '%@' not found.", self.type);
    }
    lstc.countElement = self;
}

- (void)readDataFrom:(ResourceStream *)stream
{
	UInt32 tmp = 0;
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		[stream readAmount:4 toBuffer:&tmp];
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		[stream readAmount:1 toBuffer:(char *)(&tmp)+3];
	else
		[stream readAmount:2 toBuffer:(short *)(&tmp)+1];
	
	tmp = CFSwapInt32BigToHost(tmp);
	if ([self countFromZero])
		tmp += 1;
    self.value = tmp;
}

- (void)sizeOnDisk:(UInt32 *)size
{
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		*size += 4;
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		*size += 1;
	else
		*size += 2;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt32 tmp = self.value;
	if ([self countFromZero])
		tmp -= 1;
	tmp = CFSwapInt32HostToBig(tmp);
	if ([self.type isEqualToString:@"LCNT"] || [self.type isEqualToString:@"LZCT"])
		[stream writeAmount:4 fromBuffer:&tmp];
	else if ([self.type isEqualToString:@"BCNT"] || [self.type isEqualToString:@"BZCT"])
		[stream writeAmount:1 fromBuffer:(char *)(&tmp)+3];
	else
		[stream writeAmount:2 fromBuffer:(short *)(&tmp)+1];
}

- (BOOL)countFromZero
{
	return [self.type isEqualToString:@"ZCNT"] ||
	       [self.type isEqualToString:@"BZCT"] ||
		   [self.type isEqualToString:@"WZCT"] ||
		   [self.type isEqualToString:@"LZCT"];
}

@end

