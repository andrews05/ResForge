#import <Foundation/Foundation.h>
#import "ResourceStream.h"

@interface ElementList : NSObject <NSCopying>
@property (strong) NSMutableArray<Element *> *elements;
@property (strong) NSMutableArray<Element *> *visibleElements;
@property (readonly) NSUInteger count;
@property NSUInteger currentIndex;
@property BOOL parsed;

+ (instancetype)listFromStream:(NSInputStream *)stream;

- (void)parseElements;

- (Element *)elementAtIndex:(NSUInteger)index;
- (void)insertElement:(Element *)element;
- (void)insertElement:(Element *)element before:(Element *)before;
- (void)removeElement:(Element *)element;

// For use by during readSubElements
- (Element *)peek;
- (Element *)pop;
- (Element *)nextOfType:(NSString *)type;
- (ElementList *)subListUntil:(NSString *)endType;

- (void)readDataFrom:(ResourceStream *)stream;
- (UInt32)sizeOnDisk:(UInt32)currentSize;
- (void)writeDataTo:(ResourceStream *)stream;

@end
