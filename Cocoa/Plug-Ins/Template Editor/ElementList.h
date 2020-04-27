#import <Foundation/Foundation.h>
#import "ResourceStream.h"

@interface ElementList : NSObject <NSCopying>
@property (strong) NSMutableArray<Element *> *elements;
@property (readonly) NSUInteger count;
@property NSUInteger currentIndex;

+ (instancetype)listFromStream:(NSInputStream *)stream;

- (Element *)elementAtIndex:(NSUInteger)index;
- (void)insertElement:(Element *)element;
- (void)insertElement:(Element *)element before:(Element *)before;
- (void)removeElement:(Element *)element;

// For use by during readSubElements
- (Element *)pop;
- (Element *)nextOfType:(NSString *)type;
- (ElementList *)subListUntil:(NSString *)endType;

- (void)readDataFrom:(ResourceStream *)stream;
- (UInt32)sizeOnDisk:(UInt32)currentSize;
- (void)writeDataTo:(ResourceStream *)stream;

@end
