#import "ElementKEYB.h"

@implementation ElementKEYB

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        self.editable = NO;
        self.endType = @"KEYE";
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ElementKEYB *element = [super copyWithZone:zone];
    if (!element) return nil;
    element.subElements = [self.subElements copyWithZone:zone];
    return element;
}

- (void)configure
{
    self.subElements = [self.parentList subListFor:self];
    [self.subElements configureElements];
}

- (void)readDataFrom:(ResourceStream *)stream
{
    [self.subElements readDataFrom:stream];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    [self.subElements sizeOnDisk:size];
}

- (void)writeDataTo:(ResourceStream *)stream
{
    [self.subElements writeDataTo:stream];
}

- (NSInteger)subElementCount
{
	return self.subElements.count;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	return [self.subElements elementAtIndex:n];
}

@end
