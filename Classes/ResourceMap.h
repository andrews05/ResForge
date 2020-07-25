/*
 This class is an Objective-C++ wrapper for reading and writing resource maps via libGraphite.
 It serves as a bridge between C++ and Swift.
 */

#import <Foundation/Foundation.h>

@class ResourceDocument;

NS_ASSUME_NONNULL_BEGIN

@interface ResourceMap : NSObject

+ (NSMutableArray * _Nullable)read:(NSURL *)url document:(ResourceDocument * _Nullable)document;
+ (NSString * _Nullable)write:(NSURL *)url document:(ResourceDocument *)document;

@end

NS_ASSUME_NONNULL_END
