#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

@interface Resource : NSObject <NSCopying, NSCoding, ResKnifeResourceProtocol>
{
@private
	// flags
	BOOL			dirty;
	
	// resource information
	NSString		*name;
	NSString		*type;
	NSNumber		*resID;			// signed short
	NSNumber		*attributes;	// unsigned short
	
	// the actual data
	NSData			*data;
}

- (void)setDirty:(BOOL)newValue;

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

@end
