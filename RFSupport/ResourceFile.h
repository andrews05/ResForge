/*
 This class is an Objective-C++ wrapper for reading and writing resource maps via libGraphite.
 It serves as a bridge between C++ and Swift.
 */

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ResourceFileFormat) {
    kResourceFileFormatClassic,
    kResourceFileFormatExtended,
    kResourceFileFormatRez
};

NS_ASSUME_NONNULL_BEGIN

@class Resource;

@interface ResourceFile : NSObject

+ (NSArray<Resource *> * _Nullable)readFromURL:(NSURL *)url format:(ResourceFileFormat * _Nullable)format error:(NSError ** _Nullable)outError;
+ (BOOL)writeResources:(NSArray<Resource *> *)resources toURL:(NSURL *)url asFormat:(ResourceFileFormat)format error:(NSError ** _Nullable)outError;

@end

NS_ASSUME_NONNULL_END
