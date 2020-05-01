#import "ElementRSID.h"
#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResKnifeResourceProtocol.h"

@implementation ElementRSID

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        /* Determine resource type and offset from label
         * Resource type is a 4-char code enclosed in single (or smart) quotes
         * Offset is an optional number followed by a +
         * E.g. "Extension scope info 'scop' -27136 +"
         */
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*[‘'](.{4})['’](.*?(-?[0-9]+) *[+])?" options:0 error:nil];
        NSTextCheckingResult *result = [regex firstMatchInString:l options:0 range:NSMakeRange(0, l.length)];
        if (!result) {
            // TODO: Look for preceding TNAM element to determine resource type
            NSLog(@"Could not determine resource type for RSID.");
        } else {
            self.resType = GetOSTypeFromNSString([l substringWithRange:[result rangeAtIndex:1]]);
            NSRange r = [result rangeAtIndex:3];
            if (r.location != NSNotFound) {
                self.offset = (short)[[l substringWithRange:r] intValue];
            }
        }
    }
    return self;
}

- (void)readSubElements
{
    [super readSubElements];
    if (!self.resType) return;
    if (!self.caseMap) self.caseMap = [NSMutableDictionary new];
    NSMutableArray *resCases = [NSMutableArray new];
    // Find resources in all documents
    for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        NSArray *resources = [[(ResourceDocument *)doc dataSource] allResourcesOfType:self.resType];
        for (id <ResKnifeResource> resource in resources) {
            if (!resource.name.length) continue; // No point showing resources with no name
            NSString *resID = [@(resource.resID-self.offset) stringValue];
            if (![self.caseMap valueForKey:resID]) {
                NSString *idDisplay = [self resIDDisplay:resID];
                [resCases addObject:[NSString stringWithFormat:@"%@ = %@", resource.name, idDisplay]];
                [self.caseMap setValue:[NSString stringWithFormat:@"%@ = %@", idDisplay, resource.name] forKey:resID];
            }
        }
    }
    if (resCases.count) {
        if (!self.cases) self.cases = [NSMutableArray new];
        // Sort the resources by name before adding them to the case list
        [self.cases addObjectsFromArray:[resCases sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
    }
}

- (NSString *)resIDDisplay:(NSString *)resID
{
    // If an offset is used, the value will be displayed as "value (#actual id)"
    return self.offset ? [resID stringByAppendingFormat:@" (#%d)", [resID intValue]+self.offset] : resID;
}

- (id)transformedValue:(id)value
{
    value = [value stringValue];
    return [self.caseMap valueForKey:value] ?: [self resIDDisplay:value];
}

- (id)reverseTransformedValue:(id)value
{
    value = [[value componentsSeparatedByString:@" = "] lastObject];
    if (self.offset) value = [[value componentsSeparatedByString:@" "] firstObject];
    return value ?: @"";
}

@end
