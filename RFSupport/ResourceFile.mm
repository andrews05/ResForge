#import "ResourceFile.h"
#import <Cocoa/Cocoa.h> // Required for RFSupport-Swift
#import "RFSupport/RFSupport-Swift.h"
#include "libGraphite/rsrc/file.hpp"

@implementation ResourceFile

+ (NSArray<Resource *> *)readFromURL:(NSURL *)url format:(ResourceFileFormat *)format error:(NSError **)outError
{
    graphite::rsrc::file gFile;
    try {
        gFile = graphite::rsrc::file(url.fileSystemRepresentation);
    } catch (const std::exception& e) {
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
        return nil;
    }
    if (format) *format = (ResourceFileFormat)gFile.current_format();
    NSMutableArray *resources = [NSMutableArray new];
    for (auto typeList : gFile.types()) {
        NSString *type = [NSString stringWithUTF8String:typeList->code().c_str()];
        NSMutableDictionary *typeAtts = [NSMutableDictionary new];
        for (auto attribute : typeList->attributes()) {
            NSString *key = [NSString stringWithUTF8String:attribute.first.c_str()];
            NSString *val = [NSString stringWithUTF8String:attribute.second.c_str()];
            typeAtts[key] = val;
        }
        for (auto resource : typeList->resources()) {
            // create the resource & add it to the array
            NSString    *name = [NSString stringWithUTF8String:resource->name().c_str()];
            NSData      *data = [NSData dataWithBytes:resource->data()->get()->data()+resource->data()->start() length:resource->data()->size()];
            Resource *r = [[Resource alloc] initWithType:type id:resource->id() name:name data:data typeAttributes:typeAtts];
            [resources addObject:r];
        }
    }
    return resources;
}

+ (BOOL)writeResources:(NSArray<Resource *> *)resources toURL:(NSURL *)url asFormat:(ResourceFileFormat)format error:(NSError **)outError
{
    graphite::rsrc::file gFile = graphite::rsrc::file();
    for (Resource *resource in resources) {
        std::string name(resource.name.UTF8String);
        std::string type(resource.type.UTF8String);
        char *first = (char *)resource.data.bytes; // Bytes pointer should only be accessed once
        std::vector<char> buffer(first, first+resource.data.length);
        graphite::data::data data(std::make_shared<std::vector<char>>(buffer), resource.data.length);
        std::map<std::string, std::string> attributes;
        if (format != kResourceFileFormatExtended && resource.typeAttributes.count != 0) {
            NSString *message = NSLocalizedString(@"Type attributes are not compatible with the requested file format.", "");
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{NSLocalizedFailureReasonErrorKey:message}];
            return NO;
        }
        for (NSString *att in resource.typeAttributes) {
            auto key = std::string(att.UTF8String);
            auto val = std::string(resource.typeAttributes[att].UTF8String);
            attributes.insert(std::make_pair(key, val));
        }
        gFile.add_resource(type, resource.id, name, std::make_shared<graphite::data::data>(data), attributes);
    }
    try {
        gFile.write(url.fileSystemRepresentation, (graphite::rsrc::file::format)format);
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{NSLocalizedFailureReasonErrorKey:message}];
        return NO;
    }
    return YES;
}

@end
