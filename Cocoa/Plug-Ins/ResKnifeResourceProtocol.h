#import <Foundation/Foundation.h>

/* This protocol allows your plug to interrogate a resource to find out information about it. */

@protocol ResKnifeResourceProtocol

- (BOOL)isDirty;
- (NSString *)name;
- (void)setName:(NSString *)newName;
- (NSString *)type;
- (void)setType:(NSString *)newType;
- (NSNumber *)resID;
- (void)setResID:(NSNumber *)newResID;
- (NSNumber *)attributes;
- (void)setAttributes:(NSNumber *)newAttributes;
- (NSNumber *)size;
- (NSData *)data;
- (void)setData:(NSData *)newData;

@end

// Resource notifications
// Note: when using internal notifications in your own plug-in, DO NOT use [NSNotificationCenter defaultCenter]. This is an application-wide notificaton center, use of it by plug-ins for their own means (i.e. not interacting with ResKnife) can cause conflicts with other plug-ins. You should create your own notification center and post to that.
extern NSString *ResourceWillChangeNotification;
extern NSString *ResourceNameWillChangeNotification;
extern NSString *ResourceTypeWillChangeNotification;
extern NSString *ResourceIDWillChangeNotification;
extern NSString *ResourceAttributesWillChangeNotification;
extern NSString *ResourceDataWillChangeNotification;

extern NSString *ResourceNameDidChangeNotification;
extern NSString *ResourceTypeDidChangeNotification;
extern NSString *ResourceIDDidChangeNotification;
extern NSString *ResourceAttributesDidChangeNotification;
extern NSString *ResourceDataDidChangeNotification;
extern NSString *ResourceDidChangeNotification;