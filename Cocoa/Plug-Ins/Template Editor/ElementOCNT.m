#import "ElementOCNT.h"

// implements ZCNT, OCNT, BCNT, BZCT, WCNT, WZCT, LCNT, LZCT
@implementation ElementOCNT

- (id)copyWithZone:(NSZone *)zone
{
	ElementOCNT *element = [super copyWithZone:zone];
	if(!element) return nil;
	
	// always reset counter on copy
	[element setValue:0];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	value = 0;
	if     ([type isEqualToString:@"LCNT"] || [type isEqualToString:@"LZCT"])	[stream readAmount:4 toBuffer:&value];
	else if([type isEqualToString:@"BCNT"] || [type isEqualToString:@"BZCT"])	[stream readAmount:1 toBuffer:(char *)(&value)+3];
	else																		[stream readAmount:2 toBuffer:(short *)(&value)+1];
	value = CFSwapInt32BigToHost(value);
	if([self countFromZero]) value += 1;
}

- (unsigned int)sizeOnDisk
{
	if     ([type isEqualToString:@"LCNT"] || [type isEqualToString:@"LZCT"])	return 4;
	else if([type isEqualToString:@"BCNT"] || [type isEqualToString:@"BZCT"])	return 1;
	else																		return 2;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	if([self countFromZero]) value -= 1;
	unsigned long tmp = CFSwapInt32HostToBig(value);
	if     ([type isEqualToString:@"LCNT"] || [type isEqualToString:@"LZCT"])	[stream writeAmount:4 fromBuffer:&tmp];
	else if([type isEqualToString:@"BCNT"] || [type isEqualToString:@"BZCT"])	[stream writeAmount:1 fromBuffer:(char *)(&tmp)+3];
	else																		[stream writeAmount:2 fromBuffer:(short *)(&tmp)+1];
	if([self countFromZero]) value += 1;
}

- (BOOL)countFromZero
{
	return [type isEqualToString:@"ZCNT"] ||
	       [type isEqualToString:@"BZCT"] ||
		   [type isEqualToString:@"WZCT"] ||
		   [type isEqualToString:@"LZCT"];
}

- (void)setValue:(unsigned long)v
{
	value = v;
}

- (unsigned long)value
{
	return value;
}

- (void)increment
{
	[self setValue:value+1];	// using -setValue for KVO
}

- (void)decrement
{
	if(value > 0)
		[self setValue:value-1];
}

- (NSString *)stringValue
{
	return [NSString stringWithFormat:@"%ld", value];
}

- (void)setStringValue:(NSString *)str
{
}

- (BOOL)editable
{
	return NO;
}

@end

