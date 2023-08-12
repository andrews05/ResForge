#import "ExtendedFormat.h"
#import <Cocoa/Cocoa.h> // Required for RFSupport-Swift
#import "RFSupport/RFSupport-Swift.h"
#include "libGraphite/rsrc/extended.hpp"

@implementation ExtendedFormat

+ (NSArray<Resource *> *)read:(NSData *)data error:(NSError **)outError
{
    std::vector<char> buffer((char *)data.bytes, (char *)data.bytes+data.length);
    graphite::data::data gData(std::make_shared<std::vector<char>>(buffer), data.length);
    graphite::data::reader reader(std::make_shared<graphite::data::data>(gData));
    std::vector<std::shared_ptr<graphite::rsrc::type>> types;
    try {
        types = graphite::rsrc::extended::parse(std::make_shared<graphite::data::reader>(reader));
    } catch (const std::exception& e) {
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
        return nil;
    }
    NSMutableArray *resources = [NSMutableArray new];
    for (auto typeList : types) {
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
            Resource *r = [[Resource alloc] initWithTypeCode:type typeAttributes:typeAtts id:resource->id() name:name data:data];
            [resources addObject:r];
        }
    }
    return resources;
}

+ (BOOL)write:(NSArray<NSArray<Resource *> *> *)resourcesByType toURL:(NSURL *)url error:(NSError **)outError
{
    std::vector<std::shared_ptr<graphite::rsrc::type>> types;
    for (NSArray<Resource *> *resources in resourcesByType) {
        Resource *resource = resources.firstObject;
        std::string code(resource.typeCode.UTF8String);
        std::map<std::string, std::string> attributes;
        for (NSString *att in resource.typeAttributes) {
            auto key = std::string(att.UTF8String);
            auto val = std::string(resource.typeAttributes[att].UTF8String);
            attributes.insert(std::make_pair(key, val));
        }
        auto type = std::make_shared<graphite::rsrc::type>(code, attributes);
        types.push_back(type);
        for (Resource *resource in resources) {
            std::string name(resource.name.UTF8String);
            char *first = (char *)resource.data.bytes; // Bytes pointer should only be accessed once
            auto buffer = std::make_shared<std::vector<char>>(first, first+resource.data.length);
            auto data = std::make_shared<graphite::data::data>(buffer, resource.data.length);
            auto res = std::make_shared<graphite::rsrc::resource>(resource.id, type, name, data);
            type->add_resource(res);
        }
    }
    try {
        graphite::rsrc::extended::write(url.fileSystemRepresentation, types);
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{NSLocalizedFailureReasonErrorKey:message}];
        return NO;
    }
    return YES;
}

@end
