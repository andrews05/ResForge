#import <Foundation/Foundation.h>
#import "ResourceStream.h"

@interface ElementList : NSObject <NSCopying>
@property (strong) NSMutableArray<Element *> *elements;
@property (strong) NSMutableArray<Element *> *visibleElements;
@property (readonly) NSUInteger count;
@property NSUInteger currentIndex;
@property BOOL parsed;

+ (instancetype)listFromStream:(NSInputStream *)stream;
- (instancetype)initFromStream:(NSInputStream *)stream;

- (void)parseElements;

- (Element *)elementAtIndex:(NSUInteger)index;
- (void)insertElement:(Element *)element;
- (void)insertElement:(Element *)element before:(Element *)before;
- (void)insertElement:(Element *)element after:(Element *)after;
- (void)removeElement:(Element *)element;

// For use by during readSubElements
- (Element *)peek:(NSUInteger)n;
- (Element *)pop;
- (Element *)nextOfType:(NSString *)type;
- (ElementList *)subListFrom:(Element *)startElement;

- (void)readDataFrom:(ResourceStream *)stream;
- (void)sizeOnDisk:(UInt32 *)size;
- (void)writeDataTo:(ResourceStream *)stream;

@end
