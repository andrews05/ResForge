#import "ElementLSTB.h"
#import "ElementOCNT.h"

// implements LSTB, LSTZ, LSTC
@implementation ElementLSTB

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if (self) {
		_subElements = [NSMutableArray new];
        _tail = self;
        _zeroTerminated = [t isEqualToString:@"LSTZ"];
	}
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTB *element = [super copyWithZone:zone];
	if (!element) return nil;
	
	ElementOCNT *counter = nil;
	for (Element *subToClone in self.subElements) {
        Element *clone = [subToClone copy];
        [element.subElements addObject:clone];
        clone.parentArray = element.subElements;
		if ([clone isKindOfClass:ElementOCNT.class]) {
            // Keep track of counter element
			counter = (ElementOCNT *)clone;
        } else if ([clone.type isEqualToString:@"LSTC"]) {
            // Beginning a counted sub-list, set the counter
            [(ElementLSTB *)clone setCountElement:counter];
            counter = nil;
        }
	}
	return element;
}

- (void)readSubElementsFrom:(TemplateStream *)stream
{
	while ([stream bytesToGo] > 0) {
		Element *element = [stream readOneElement];
        if ([element.type isEqualToString:@"LSTE"]) {
			break;
		}
		[self.subElements addObject:element];
	}
}

- (void)readNextItem:(TemplateStream *)stream toIndex:(NSUInteger)index
{
    ElementLSTB *nextItem = [self.tail copy]; // Make another list item just like this one.
    [self.parentArray insertObject:nextItem atIndex:index];   // Add it before ourselves.
    [self.entries addObject:nextItem];
    nextItem.parentArray = self.parentArray;
    nextItem.tail = self;
    nextItem.countElement = self.countElement;
    // Copy to avoid possible problems with mutation
	for (Element *element in [nextItem.subElements copy]) {
		[element readDataFrom:stream];
	}
}

- (void)readDataFrom:(TemplateStream *)stream
{
    // This item will be the tail
    NSUInteger index = [self.parentArray indexOfObject:self];
    self.entries = [NSMutableArray new];
    
    if ([self.type isEqualToString:@"LSTC"]) {
        if (!self.countElement) self.countElement = [stream popCounter];
        for (unsigned int i = 0; i < self.countElement.value; i++) {
            [self readNextItem:stream toIndex:index++];
        }
        if ([self.countElement.type isEqualToString:@"FCNT"]) {
            // FCNT should not show the tail
            [self.parentArray removeObjectAtIndex:index];
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
            [self readNextItem:stream toIndex:index++];
        }
    }
    
    [self.entries addObject:self];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    UInt32 size = 0;
    if (self != self.tail) {
        for (Element *element in self.subElements) {
            size += [element sizeOnDisk:(currentSize + size)];
        }
    } else if (_zeroTerminated) {
        size = 1;
    }
	return size;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    if (self != self.tail) {
        // Writes out the data of all our sub-elements here:
        for (Element *element in self.subElements) {
            [element writeDataTo:stream];
        }
    } else if (_zeroTerminated) {
        [stream advanceAmount:1 pad:YES];
    }
}

- (NSString *)label
{
    // Prefix with item number
    NSUInteger index = [self.tail.entries indexOfObject:self];
    return [NSString stringWithFormat:@"%ld) %@", index+1, super.label];
}

#pragma mark -

- (NSInteger)subElementCount
{
    return self == self.tail ? 0 : self.subElements.count;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	return self.subElements[n];
}

- (BOOL)createListEntry
{
    if ([self.countElement.type isEqualToString:@"FCNT"])
        return NO;
    
    ElementLSTB *list = [self.tail copy];
    [self.parentArray insertObject:list atIndex:[self.parentArray indexOfObject:self]];
    [self.tail.entries insertObject:list atIndex:[self.tail.entries indexOfObject:self]];
    list.parentArray = self.parentArray;
    list.tail = self.tail;
    list.countElement = self.countElement;
    self.countElement.value++;
    return YES;
}

- (BOOL)removeListEntry
{
    if ([self.countElement.type isEqualToString:@"FCNT"])
        return NO;
    
	[self.parentArray removeObject:self];
    [self.tail.entries removeObject:self];
    self.countElement.value--;
    return YES;
}

@end
