#import <Foundation/Foundation.h>
#import "ResourceStream.h"

@class TemplateWindowController;

@interface ElementList : NSObject <NSCopying>
@property (strong) NSMutableArray<Element *> *elements;
@property (strong) NSMutableArray<Element *> *visibleElements;
@property (strong) ElementList *parentList;
@property (readonly) NSUInteger count;
@property (readonly) NSUInteger currentIndex;
@property (weak) TemplateWindowController *controller;
@property BOOL parsed;

+ (instancetype)listFromStream:(NSInputStream *)stream;
- (instancetype)initFromStream:(NSInputStream *)stream;

- (void)parseElements;

- (__kindof Element *)elementAtIndex:(NSUInteger)index;
- (void)insertElement:(Element *)element;
- (void)insertElement:(Element *)element before:(Element *)before;
- (void)insertElement:(Element *)element after:(Element *)after;
- (void)removeElement:(Element *)element;

// For use by during readSubElements
- (__kindof Element *)peek:(NSUInteger)n;
- (__kindof Element *)pop;
- (__kindof Element *)nextOfType:(NSString *)type;
- (__kindof Element *)previousOfType:(NSString *)type;
- (ElementList *)subListFor:(Element *)startElement;

- (void)readDataFrom:(ResourceStream *)stream;
- (void)sizeOnDisk:(UInt32 *)size;
- (void)writeDataTo:(ResourceStream *)stream;

@end
