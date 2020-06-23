#import "Element.h"

@interface ElementBOOL : Element
@property UInt8 value;

+ (NSButton *)createCheckboxWithFrame:(NSRect)frame forElement:(Element *)element;

@end
