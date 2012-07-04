#import <Foundation/Foundation.h>
#import "../Plug-Ins/ResKnifeResourceProtocol.h"

/*!
@class			Resource
@author			Nicholas Shanks
@abstract		Encapsulates a single resource and all associated meta-data.
@description	The Resource class fully complies with key-value coding, with the keys @"name", @"type", @"resID", @"attributes", @"data", @"dirty" and @"representedFork" available.
*/

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
	
	// the document name for display to the user; updating this is the responsibility of the document itself
	NSString		*_docName;
}

// accessor methods not part of the protocol
- (void)_setName:(NSString *)newName;
- (void)setDirty:(BOOL)newValue;
- (NSString *)representedFork;
- (void)setRepresentedFork:(NSString *)forkName;
- (void)setDocumentName:(NSString *)docName;

// init methods
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
- (id)initWithType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

// autoreleased resource methods
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue;
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue withName:(NSString *)nameValue andAttributes:(NSNumber *)attributesValue data:(NSData *)dataValue;

+ (Resource *)getResourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)searchDoc;

@end
