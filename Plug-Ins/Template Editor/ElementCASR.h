#import "ElementCaseable.h"

@class ElementRangeable;

@interface ElementCASR : ElementCaseable
@property int value;
@property int min;
@property int max;
@property int offset;
@property BOOL invert;
@property OSType resType;
@property (strong) NSView *view;
@property ElementRangeable *parentElement;

- (BOOL)matchesValue:(NSNumber *)value;
- (id)normalise:(id)value;
- (id)deNormalise:(id)value;

@end
