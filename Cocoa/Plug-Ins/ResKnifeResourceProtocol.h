#import <Foundation/Foundation.h>

/* This protocol allows your plug to interrogate a resource to find out information about it. */

@protocol ResKnifeResourceProtocol

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

@end