#import "Element.h"

@interface ElementDLNG : Element
{
	SInt32 value;
}
@property SInt32 value;
@property (weak) NSString *stringValue;

@end

@interface ElementKLNG : ElementDLNG
@end
