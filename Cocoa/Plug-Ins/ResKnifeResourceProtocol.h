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
- (void)setDirty:(BOOL)newValue;	// bug: may not be around forever
- (NSData *)data;
- (void)setData:(NSData *)newData;

@end

// Resource notifications
extern NSString *ResourceChangedNotification;		// Note: when using internal notifications in your own plug-in, DO NOT use [NSNotificationCenter defaultCenter]. This is an application-wide notificaton center, use of it by plug-ins for their own means (i.e. not interacting with ResKnife) can cause conflicts with other plug-ins. You should create your own notification center and post to that.