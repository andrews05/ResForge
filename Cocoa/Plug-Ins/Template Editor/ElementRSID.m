#import "ElementRSID.h"
#import "ElementCASE.h"
#import "Resource.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResKnifeResourceProtocol.h"

@implementation ElementRSID
@synthesize resType = _resType;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        /*
         * Determine resource type and offset from label
         * Resource type is a 4-char code enclosed in single (or smart) quotes
         * Offset is a number followed by a +
         * E.g. "Extension scope info 'scop' -27136 +"
         */
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:.*[‘'](.{4})['’])?(?:.*?(-?[0-9]+) *[+])?" options:0 error:nil];
        NSTextCheckingResult *result = [regex firstMatchInString:l options:0 range:NSMakeRange(0, l.length)];
        NSRange r = [result rangeAtIndex:1];
        if (r.location != NSNotFound) {
            _resType = GetOSTypeFromNSString([l substringWithRange:[result rangeAtIndex:1]]);
        }
        r = [result rangeAtIndex:2];
        if (r.location != NSNotFound) {
            _offset = (short)[[l substringWithRange:r] intValue];
        }
    }
    return self;
}

- (OSType)resType
{
    return _resType;
}

- (void)setResType:(OSType)resType
{
    _resType = resType;
    [self loadCases];
}

- (void)readSubElements
{
    if (!self.resType) {
        // See if we can bind to a preceding TNAM field
        Element *tnam = [self.parentList previousOfType:@"TNAM"];
        if (!tnam) {
            NSLog(@"Could not determine resource type for RSID.");
            [super readSubElements];
            return;
        }
        [self bind:@"resType" toObject:tnam withKeyPath:@"tnam" options:nil];
    }
    self.fixedCases = [NSMutableArray new];
    Element *element = [self.parentList peek:1];
    while (element.class == ElementCASE.class) {
        [self.fixedCases addObject:[self.parentList pop]];
        element = [self.parentList peek:1];
    }
    self.caseMap = [NSMutableDictionary new];
    [self loadCases];
}

- (void)loadCases
{
    NSMutableArray *cases = [NSMutableArray new];
    [self.caseMap removeAllObjects];
    for (ElementCASE *element in self.fixedCases) {
        NSString *option = [NSString stringWithFormat:@"%@ = %@", element.symbol, element.value];
        NSString *display = [NSString stringWithFormat:@"%@ = %@", element.value, element.symbol];
        [cases addObject:option];
        [self.caseMap setObject:display forKey:element.value];
    }
    if (self.resType) {
        // Find resources in all documents
        NSMutableArray *resCases = [NSMutableArray new];
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
        // Sort the resources by name before adding them to the list
        [cases addObjectsFromArray:[resCases sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
    }
    self.cases = cases; // This triggers the combo box refresh
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
