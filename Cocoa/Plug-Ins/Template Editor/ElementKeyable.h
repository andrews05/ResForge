#import "ElementCaseable.h"
#import "ElementKEYB.h"

@interface ElementKeyable : ElementCaseable
@property BOOL isKeyed;
@property (strong) NSMutableDictionary *keyedSections;
@property (strong) ElementKEYB *currentSection;

- (void)readCases;

@end
