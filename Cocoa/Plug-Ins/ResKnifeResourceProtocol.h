#import <Cocoa/Cocoa.h>

/* This protocol allows your plug to interrogate a resource to find out information about it. */

@protocol ResKnifeResourceProtocol

- (void)touch;
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

// These methods are used to retrieve resources other than the one you're editing.
//	Passing a document of nil will indicate to search in all open documents.
//	There is currently no way to search in files which haven't been opened.
//	All returned objects are auoreleased. Retain if you want to keep them.

//	This method may return an empty array
+ (NSArray *)allResourcesOfType:(NSString *)typeValue inDocument:(NSDocument *)document;
//	The next two return the first matching resource found, or nil.
+ (id)resourceOfType:(NSString *)typeValue andID:(NSNumber *)resIDValue inDocument:(NSDocument *)document;
+ (id)resourceOfType:(NSString *)typeValue withName:(NSString *)nameValue inDocument:(NSDocument *)document;

@end

// Resource notifications
//	See note in Notifications.m about usage
extern NSString *ResourceWillChangeNotification;
extern NSString *ResourceNameWillChangeNotification;
extern NSString *ResourceTypeWillChangeNotification;
extern NSString *ResourceIDWillChangeNotification;
extern NSString *ResourceAttributesWillChangeNotification;
extern NSString *ResourceDataWillChangeNotification;
extern NSString *ResourceWillBeSavedNotification;

extern NSString *ResourceNameDidChangeNotification;
extern NSString *ResourceTypeDidChangeNotification;
extern NSString *ResourceIDDidChangeNotification;
extern NSString *ResourceAttributesDidChangeNotification;
extern NSString *ResourceDataDidChangeNotification;
extern NSString *ResourceDidChangeNotification;
extern NSString *ResourceWasSavedNotification;