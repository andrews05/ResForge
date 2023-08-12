/*
 This class is an Objective-C++ wrapper for reading and writing resource maps via libGraphite.
 It serves as a bridge between C++ and Swift.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Resource;

@interface ExtendedFormat : NSObject

+ (NSArray<Resource *> * _Nullable)read:(NSData *)data error:(NSError ** _Nullable)outError;
+ (BOOL)write:(NSArray<NSArray<Resource *> *> *)resourcesByType toURL:(NSURL *)url error:(NSError ** _Nullable)outError;

@end

NS_ASSUME_NONNULL_END
