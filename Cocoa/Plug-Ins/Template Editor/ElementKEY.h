#import "Element.h"
#import "ElementKEYB.h"

@interface ElementKEY : Element
@property BOOL isKey;
@property BOOL observing;
@property (strong) NSMutableDictionary *keyedSections;
@property (strong) ElementKEYB *currentSection;

- (void)readCases;

@end
