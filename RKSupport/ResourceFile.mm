#import "ResourceFile.h"
#import "RKSupport/RKSupport-Swift.h"
#include "libGraphite/rsrc/file.hpp"

@implementation ResourceFile

+ (NSArray<Resource *> *)readFromURL:(NSURL *)url format:(ResourceFileFormat *)format error:(NSError **)outError
{
    graphite::rsrc::file gFile;
    try {
        gFile = graphite::rsrc::file(url.fileSystemRepresentation);
    } catch (const std::exception& e) {
        NSString *message = [NSString stringWithUTF8String:e.what()];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{NSLocalizedFailureReasonErrorKey:message}];
        return nil;
    }
    if (format) *format = (ResourceFileFormat)gFile.current_format();
    NSMutableArray* resources = [NSMutableArray new];
    for (auto typeList : gFile.types()) {
        for (auto resource : typeList->resources()) {
            // create the resource & add it to the array
            NSString    *name = [NSString stringWithUTF8String:resource->name().c_str()];
            NSString    *type = [NSString stringWithUTF8String:typeList->code().c_str()];
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
    for (Resource* resource in resources) {
        std::string name([resource.name UTF8String]);
        std::string type([resource.type UTF8String]);
        std::vector<char> buffer((char *)resource.data.bytes, (char *)resource.data.bytes+resource.data.length);
        graphite::data::data data(std::make_shared<std::vector<char>>(buffer), resource.data.length);
        gFile.add_resource(type, resource.id, name, std::make_shared<graphite::data::data>(data));
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
