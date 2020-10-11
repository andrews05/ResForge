#import "ElementLSTB.h"
#import "ElementDVDR.h"
#import "Template_Editor-Swift.h"

// implements LSTB, LSTZ, LSTC
@implementation ElementLSTB

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	if (self = [super initForType:t withLabel:l]) {
        _zeroTerminated = [t isEqualToString:@"LSTZ"];
        self.rowHeight = 18;
        self.endType = @"LSTE";
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTB *element = [super copyWithZone:zone];
	if (!element) return nil;
    element.subElements = [self.subElements copyWithZone:zone];
    [element checkSingleElement];
    element.tail = self.tail;
    element.entries = self.entries;
	return element;
}

- (NSString *)displayLabel
{
    NSUInteger index = [self.entries indexOfObject:self];
    return [NSString stringWithFormat:@"%ld) %@", index+1, self.singleElement.displayLabel ?: super.displayLabel];
}

- (NSString *)tooltip
{
    return self.singleElement.tooltip ?: super.tooltip;
}

// If the list entry contains only a single visible element, show that element here while hiding the sub section
// (this also greatly improves performance with large lists)
- (void)configureView:(NSView *)view
{
    [self.singleElement configureView:view];
}

- (void)configure
{
    self.entries = [NSMutableArray arrayWithObject:self];
    self.subElements = [self.parentList subListFor:self];
    if ([self.countElement.type isEqualToString:@"FCNT"]) {
        // Fixed count list, create all the entries now
        for (unsigned int i = 1; i < self.countElement.value; i++) {
            [self createNextItem];
        }
        [self.subElements configureElements];
        [self checkSingleElement];
    } else {
        // This item will be the tail
        self.tail = self;
    }
}

- (void)checkSingleElement
{
    if (self.subElements.count == 1) {
        self.singleElement = [self.subElements elementAt:0];
        self.rowHeight = 22;
    }
}

- (ElementLSTB *)createNextItem
{
    // Create a new list entry at the current index (just before self)
    ElementLSTB *list = [self copy];
    [self.parentList insert:list];
    [self.entries addObject:list];
    return list;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.tail) {
        [self.subElements readDataFrom:stream];
        return;
    }
    
    [self.entries removeAllObjects];
    if ([self.type isEqualToString:@"LSTC"]) {
        for (unsigned int i = 0; i < self.countElement.value; i++) {
            [[self createNextItem].subElements readDataFrom:stream];
        }
    } else {
        while ([stream bytesToGo] > 0) {
            if (_zeroTerminated) {
                char termByte = 0;
                [stream peekAmount:1 toBuffer:&termByte];
                if (termByte == 0) {
                    [stream advanceAmount:1 pad:NO];
                    break;
                }
            }
            [[self createNextItem].subElements readDataFrom:stream];
        }
    }
    [self.entries addObject:self];
}

- (void)sizeOnDisk:(UInt32 *)size
{
    if (self != self.tail) {
        *size += [self.subElements sizeOnDisk];
    } else if (_zeroTerminated) {
        *size += 1;
    }
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if (self != self.tail) {
        // Writes out the data of all our sub-elements here:
        [self.subElements writeDataTo:stream];
    } else if (_zeroTerminated) {
        [stream advanceAmount:1 pad:YES];
    }
}

#pragma mark -

- (BOOL)hasSubElements
{
    if (self.singleElement)
        return self.singleElement.hasSubElements;
    return self != self.tail;
}

- (NSInteger)subElementCount
{
    if (self.singleElement)
        return self.singleElement.subElementCount;
    return self == self.tail ? 0 : self.subElements.count;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
    if (self.singleElement)
        return [self.singleElement subElementAtIndex:n];
    return [self.subElements elementAt:n];
}

- (BOOL)allowsCreateListEntry
{
    return self.tail != nil;
}

- (BOOL)allowsRemoveListEntry
{
    return self.tail != nil && self.tail != self;
}

- (void)createListEntry
{
    ElementLSTB *list = [self.tail copy];
    [self.parentList insert:list before:self];
    [self.entries insertObject:list atIndex:[self.entries indexOfObject:self]];
    self.tail.countElement.value++;
}

- (void)removeListEntry
{
	[self.parentList remove:self];
    [self.entries removeObject:self];
    self.tail.countElement.value--;
}

@end
