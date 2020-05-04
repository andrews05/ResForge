#import "ElementLSTB.h"

// implements LSTB, LSTZ, LSTC
@implementation ElementLSTB

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if (self) {
        _tail = self;
        _zeroTerminated = [t isEqualToString:@"LSTZ"];
        self.editable = NO;
        self.endType = @"LSTE";
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTB *element = [super copyWithZone:zone];
	if (!element) return nil;
    element.subElements = [self.subElements copyWithZone:zone];
    if (element.subElements.count == 1) {
        element.singleItem = [element.subElements elementAtIndex:0];
    }
	return element;
}

// If the list entry contains only a single visible element, show that element here while hiding the sub section
// (this also greatly improves performance with large lists)
- (NSView *)dataView:(NSOutlineView *)outlineView
{
    return [self.singleItem dataView:outlineView];
}

- (void)readSubElements
{
    // This item will be the tail
    self.entries = [NSMutableArray arrayWithObject:self];
    self.subElements = [self.parentList subListFor:self];
    if ([self.countElement.type isEqualToString:@"FCNT"]) {
        // Fixed count list, create all the entries now
        self.tail = nil;
        for (unsigned int i = 1; i < self.countElement.value; i++) {
            [self createNextItem];
        }
        [self.subElements parseElements];
        if (self.subElements.count == 1) {
            self.singleItem = [self.subElements elementAtIndex:0];
        }
    }
}

- (ElementLSTB *)createNextItem
{
    // Create a new list entry at the current index (just before self)
    ElementLSTB *list = [self copy];
    [self.parentList insertElement:list];
    [self.entries addObject:list];
    list.tail = self.tail;
    list.entries = self.entries;
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
        [self.subElements sizeOnDisk:size];
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

- (NSString *)label
{
    // Prefix with item number
    NSUInteger index = [self.entries indexOfObject:self];
    return [NSString stringWithFormat:@"%ld) %@", index+1, [self.singleItem label] ?: super.label];
}

#pragma mark -

- (NSInteger)subElementCount
{
    return (self == self.tail || self.singleItem) ? 0 : self.subElements.count;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
    return [self.subElements elementAtIndex:n];
}

- (BOOL)createListEntry
{
    if (!self.tail) return NO;
    
    ElementLSTB *list = [self.tail copy];
    [self.parentList insertElement:list before:self];
    [self.entries insertObject:list atIndex:[self.entries indexOfObject:self]];
    self.tail.countElement.value++;
    list.tail = self.tail;
    list.entries = self.entries;
    return YES;
}

- (BOOL)removeListEntry
{
    if (!self.tail || self == self.tail) return NO;
    
	[self.parentList removeElement:self];
    [self.entries removeObject:self];
    self.tail.countElement.value--;
    return YES;
}

@end
