#import "ResourceMap.h"
#import "ResourceDocument.h"
#import "Resource.h"
#include "libGraphite/rsrc/file.hpp"

@implementation ResourceMap

+ (NSMutableArray *)read:(NSURL *)url document:(ResourceDocument *)document
{
    graphite::rsrc::file gFile;
    try {
        gFile = graphite::rsrc::file(url.fileSystemRepresentation);
    } catch (const std::exception& e) {
        return nil;
    }
    if (document) document.format = (FileFormat)gFile.current_format();
    NSMutableArray* resources = [NSMutableArray new];
    for (auto type : gFile.types()) {
        for (auto resource : type->resources()) {
            // create the resource & add it to the array
            NSString    *name       = [NSString stringWithUTF8String:resource->name().c_str()];
            NSString    *resType    = [NSString stringWithUTF8String:type->code().c_str()];
            NSData      *data       = [NSData dataWithBytes:resource->data()->get()->data()+resource->data()->start() length:resource->data()->size()];
            Resource *r = [Resource resourceOfType:GetOSTypeFromNSString(resType) andID:(SInt16)resource->id() withName:name andAttributes:0 data:data];
            [resources addObject:r]; // array retains resource
            r.document = document;
        }
    }
    return resources;
}

+ (NSString *)write:(NSURL *)url document:(ResourceDocument *)document
{
    graphite::rsrc::file gFile = graphite::rsrc::file();
    for (Resource* resource in [document.dataSource resources]) {
        std::string name([resource.name UTF8String]);
        std::string resType([GetNSStringFromOSType(resource.type) UTF8String]);
        std::vector<char> buffer((char *)resource.data.bytes, (char *)resource.data.bytes+resource.size);
        graphite::data::data data(std::make_shared<std::vector<char>>(buffer), resource.size);
        gFile.add_resource(resType, resource.resID, name, std::make_shared<graphite::data::data>(data));
    }
    try {
        gFile.write(url.fileSystemRepresentation, (graphite::rsrc::file::format)document.format);
    } catch (const std::exception& e) {
        return [NSString stringWithUTF8String:e.what()];
    }
    return nil;
}

@end
