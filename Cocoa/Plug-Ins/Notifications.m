/*	Notifications.
	Include this file in your target to access these notifications.
	
	Note: when using internal notifications in your own plug-in, DO NOT use [NSNotificationCenter defaultCenter]. This is an application-wide notificaton center, use of it by plug-ins for their own means (i.e. not interacting with ResKnife) can cause conflicts with other plug-ins. You should create your own notification center and post to that.
*/

#import <Foundation/Foundation.h>

NSString *ResourceWillChangeNotification			= @"ResourceWillChangeNotification";
NSString *ResourceNameWillChangeNotification		= @"ResourceNameWillChangeNotification";
NSString *ResourceTypeWillChangeNotification		= @"ResourceTypeWillChangeNotification";
NSString *ResourceIDWillChangeNotification			= @"ResourceIDWillChangeNotification";
NSString *ResourceAttributesWillChangeNotification	= @"ResourceAttributesWillChangeNotification";
NSString *ResourceDataWillChangeNotification		= @"ResourceDataWillChangeNotification";

NSString *ResourceNameDidChangeNotification			= @"ResourceNameDidChangeNotification";
NSString *ResourceTypeDidChangeNotification			= @"ResourceTypeDidChangeNotification";
NSString *ResourceIDDidChangeNotification			= @"ResourceIDDidChangeNotification";
NSString *ResourceAttributesDidChangeNotification	= @"ResourceAttributesDidChangeNotification";
NSString *ResourceDataDidChangeNotification			= @"ResourceDataDidChangeNotification";
NSString *ResourceDidChangeNotification				= @"ResourceDidChangeNotification";