#import "ElementLSTB.h"

// implements LSTB, LSTZ, LSTC
@implementation ElementLSTB

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super initForType:t withLabel:l];
	if (self) {
        _tail = self;
        _zeroTerminated = [t isEqualToString:@"LSTZ"];
	}
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ElementLSTB *element = [super copyWithZone:zone];
	if (!element) return nil;
    element.subElements = [self.subElements copyWithZone:zone];
	return element;
}

- (void)readSubElements
{
    // This item will be the tail
    self.entries = [NSMutableArray new];
    self.subElements = [self.parentList subListUntil:@"LSTE"];
    if ([self.countElement.type isEqualToString:@"FCNT"]) {
        // Fixed count list, create all the entries now
        self.tail = nil;
        for (unsigned int i = 1; i < self.countElement.value; i++) {
            [self createNextItem];
        }
        [self.subElements parseElements];
        [self.entries addObject:self];
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
            ;
            [[self createNextItem].subElements readDataFrom:stream];
        }
    }
    [self.entries addObject:self];
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    if (self != self.tail) {
        return [self.subElements sizeOnDisk:currentSize];
    } else if (_zeroTerminated) {
        return 1;
    }
	return 0;
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
    return [NSString stringWithFormat:@"%ld) %@", index+1, super.label];
}

#pragma mark -

- (NSInteger)subElementCount
{
    return self == self.tail ? 0 : self.subElements.count;
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
    if (!self.tail) return NO;
    
	[self.parentList removeElement:self];
    [self.entries removeObject:self];
    self.tail.countElement.value--;
    return YES;
}

@end
