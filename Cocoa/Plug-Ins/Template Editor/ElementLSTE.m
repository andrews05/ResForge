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

- (IBAction)createListEntry:(id)sender
{
	ElementLSTB *list = [groupElementTemplate copy];
	[parentArray insertObject:list atIndex:[parentArray indexOfObject:self]];
	[list setParentArray:parentArray];
	[list setCountElement:countElement];
	[countElement increment];
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

@end
