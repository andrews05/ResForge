#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

extern NSString *ResourceChangedNotification;

@interface Resource : NSObject <ResKnifeResourceProtocol>
{
@private
	// resource information
	NSString		*name;
	NSString		*type;
	NSNumber		*resID;			// signed short
	NSNumber		*size;			// unsigned long
	NSNumber		*attributes;	// unsigned short
	
	// flags
	BOOL		dirty;
	
	// the actual data
	NSData		*data;
}

- (NSString *)name;
- (void)setName:(NSString *)newName;
- (NSString *)type;
- (void)setType:(NSString *)newType;
- (NSNumber *)resID;
- (void)setResID:(NSNumber *)newResID;
- (NSNumber *)size;
- (void)setSize:(NSNumber *)newSize;
- (NSNumber *)attributes;
- (void)setAttributes:(NSNumber *)newAttributes;
- (BOOL)dirty;
- (void)setDirty:(BOOL)newValue;
- (NSData *)data;
- (void)setData:(NSData *)newData;

- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue ofLength:(NSNumber *)sizeValue;

+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue ofLength:(NSNumber *)sizeValue;

@end
