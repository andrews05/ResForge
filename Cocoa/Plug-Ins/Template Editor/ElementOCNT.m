#import "ElementOCNT.h"
#import "ElementULNG.h"

// implements ZCNT, OCNT, BCNT, BZCT, WCNT, WZCT, LCNT, LZCT
@implementation ElementOCNT
@synthesize value;

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSTableCellView *view = (NSTableCellView *)[super outlineView:outlineView viewForTableColumn:tableColumn];
    view.textField.editable = NO;
    return view;
}

- (void)readDataFrom:(TemplateStream *)stream
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
    value = tmp;
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
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
    UInt32 tmp = value;
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

