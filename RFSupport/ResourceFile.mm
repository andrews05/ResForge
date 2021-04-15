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
        auto typeString = typeList->code();
        // Type attributes are a feature of the extended format. For preliminary support, just combine these into the type code.
        for (auto attribute : typeList->attributes()) {
            typeString += ":" + attribute.first + "=" + attribute.second;
        }
        NSString *type = [NSString stringWithUTF8String:typeString.c_str()];
        for (auto resource : typeList->resources()) {
            // create the resource & add it to the array
            NSString    *name = [NSString stringWithUTF8String:resource->name().c_str()];
            NSData      *data = [NSData dataWithBytes:resource->data()->get()->data()+resource->data()->start() length:resource->data()->size()];
            Resource *r = [[Resource alloc] initWithType:type id:resource->id() name:name attributes:0 data:data];
            [resources addObject:r];
        }
    }
    return resources;
}

+ (BOOL)writeResources:(NSArray<Resource *> *)resources toURL:(NSURL *)url withFormat:(ResourceFileFormat)format error:(NSError **)outError
{
    graphite::rsrc::file gFile = graphite::rsrc::file();
    for (Resource *resource in resources) {
        std::string name(resource.name.UTF8String);
        std::string type([resource.type substringToIndex:4].UTF8String);
        char *first = (char *)resource.data.bytes; // Bytes pointer should only be accessed once
        std::vector<char> buffer(first, first+resource.data.length);
        graphite::data::data data(std::make_shared<std::vector<char>>(buffer), resource.data.length);
        std::map<std::string, std::string> attributes;
        if (resource.type.length > 5) {
            NSString *attString = [resource.type substringFromIndex:5];
            for (NSString *attribute in [attString componentsSeparatedByString:@":"]) {
                NSArray<NSString *> *parts = [attribute componentsSeparatedByString:@"="];
                attributes.insert(std::make_pair(std::string(parts[0].UTF8String), std::string(parts[1].UTF8String)));
            }
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
