#import "Element.h"

@interface ElementDATE : Element
{
	// seconds since 1 Jan 1904
	UInt32 value;
}
@property UInt32 value;
@property (assign) NSString *stringValue;

@end
