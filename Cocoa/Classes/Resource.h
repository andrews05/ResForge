#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

@interface Resource : NSObject <NSCopying, NSCoding, ResKnifeResourceProtocol>
{
@private
	// flags
	BOOL			dirty;
	NSString		*representedFork;
	
	// resource information
	NSString		*name;
	NSString		*type;
	NSNumber		*resID;			// signed short
	NSNumber		*attributes;	// unsigned short
	
	// the actual data
	NSData			*data;
}

// accessor methods not part of the protocol
- (void)setDirty:(BOOL)newValue;
- (NSString *)representedFork;
- (void)setRepresentedFork:(NSString *)forkName;

// init methods
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

// autoreleased resource methods
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

@end
