#import <Foundation/Foundation.h>

@interface Element : NSObject
{
	NSString	*label;
	NSString	*type;
}

- (id)initWithType:(NSString *)typeValue andLabel:(NSString *)labelValue;
+ (id)elementOfType:(NSString *)typeValue withLabel:(NSString *)labelValue;

@end
