#import "ElementLSTE.h"
#import "ElementLSTB.h"
#import "ElementOCNT.h"

@implementation ElementLSTE
@synthesize writesZeroByte;
@synthesize groupElementTemplate;
@synthesize countElement;
@dynamic stringValue;

- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTE *element = [super copyWithZone:zone];
	[element setGroupElementTemplate:groupElementTemplate];
	[element setWritesZeroByte:writesZeroByte];
	[element setCountElement:countElement];
	return element;
}


- (void)readSubElementsFrom:(TemplateStream *)stream
{
}

- (void)readDataFrom:(TemplateStream *)stream
{
	if(writesZeroByte)
		[stream advanceAmount:1 pad:NO];
}

- (unsigned int)sizeOnDisk
{
	return writesZeroByte? 1:0;
}

- (void)writeDataTo:(TemplateStream *)stream
{
	if(writesZeroByte)
		[stream advanceAmount:1 pad:YES];
}

- (void)setWritesZeroByte:(BOOL)n
{
	writesZeroByte = n;
}

- (BOOL)writesZeroByte
{
	return writesZeroByte;
}

- (BOOL)createListEntry
{
    if ([countElement.type isEqualToString:@"FCNT"])
        return NO;
    
	ElementLSTB *list = [groupElementTemplate copy];
	[self.parentArray insertObject:list atIndex:[self.parentArray indexOfObject:self]];
	[list setParentArray:self.parentArray];
	[list setCountElement:countElement];
	[countElement addEntry:list after:nil];
    return YES;
}

- (NSString *)stringValue
{
	return @"";
}

- (void)setStringValue:(NSString *)str
{
}

- (BOOL)editable
{
	return NO;
}

- (NSString *)label
{
    if (self.countElement == nil) return super.label;
    NSUInteger index = [[self.countElement entries] count]+1;
    return [NSString stringWithFormat:@"%ld) %@", index, super.label];
}

@end
