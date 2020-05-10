#import "ElementCASR.h"
#import "ElementRangeable.h"
#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResKnifeResourceProtocol.h"

/*
 * The CASR element is an experimental case range element
 * It allows an element's value to have different interpretations based on a range that the value falls into
 * An element with CASRs shows a popup button to select the case range, followed by a text field to enter a value within that range
 * The CASR label format looks like "Display Label=minValue,maxValue normal 'TNAM'"
 * At least one of minValue and maxValue must be provided, the remainder is optional
 * The normal, if given, will normalise the value displayed in the text field - it represents what the minValue will display as
 * If minValue is greater than maxValue, the normalised values will be inverted
 * If a TNAM is provided, the text field will be combo box allowing you to select a resource of this type within the normalised range
 * A CASR may also be just a single value like a CASE, in which case no text field will be shown for this option
 * Note that you cannot associate both CASEs and CASRs to the same element
 */
@implementation ElementCASR

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.visible = NO;
        // Determine parameters from label
        NSArray *components = [l componentsSeparatedByString:@"="];
        BOOL valid = NO;
        if (components.count > 1) {
            NSScanner *scanner = [NSScanner scannerWithString:components[1]];
            if ([scanner scanInt:&_min]) {
                valid = YES;
            } else {
                _min = INT32_MIN;
            }
            if ([scanner scanString:@"," intoString:nil]) {
                if ([scanner scanInt:&_max]) {
                    valid = YES;
                } else {
                    _max = INT32_MAX;
                }
                int normal;
                if ([scanner scanInt:&normal]) {
                    _invert = _min > _max;
                    _offset = (_invert ? -_min : _min) - normal;
                    _min = normal;
                    _max = (_invert ? -_max : _max) - _offset;
                }
                if ([scanner scanString:@"'" intoString:nil]) {
                    NSString *resType;
                    [scanner scanUpToString:@"'" intoString:&resType];
                    if ([scanner scanString:@"'" intoString:nil]) {
                        _resType = GetOSTypeFromNSString(resType);
                    }
                }
            } else {
                // Single value
                _max = _min;
            }
        }
        if (!valid) {
            NSLog(@"Could not determine parameters for CASR.");
        }
    }
    return self;
}

- (NSString *)description
{
    return self.displayLabel;
}

- (void)configure
{
    NSLog(@"CASR element not associated to an element that supports case ranges.");
}

- (void)configureView:(NSView *)view
{
    if (self.min == self.max) return;
    [self loadCases];
    [super configureView:view];
    // Reposition the control if the select menu exists
    if (self.parentElement.cases.count > 1) {
        NSView *subview = [view.subviews lastObject];
        NSRect frame = subview.frame;
        frame.origin.x = view.subviews[0].frame.size.width + 4;
        subview.frame = frame;
    }
}

- (int)value
{
    return self.parentElement.displayValue;
}

- (void)setValue:(int)value
{
    self.parentElement.displayValue = value;
}

- (void)loadCases
{
    if (!self.resType || self.cases) return;
    // If a resType has been given this will become a combo box for resource selection
    self.width = self.parentElement.cases.count > 1 ? 180 : 240;
    self.cases = [NSMutableArray new];
    self.caseMap = [NSMutableDictionary new];
    // Find resources in all documents
    NSMutableArray *allResources = [NSMutableArray new];
    for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        NSArray *resources = [[(ResourceDocument *)doc dataSource] allResourcesOfType:self.resType];
        for (id <ResKnifeResource> resource in resources) {
            if (!resource.name.length) continue; // No point showing resources with no name
            if (resource.resID < self.min || resource.resID > self.max) continue;
            NSString *resID = @(resource.resID).stringValue;
            if (![self.caseMap objectForKey:resID]) {
                [allResources addObject:resource];
                [self.caseMap setObject:[NSString stringWithFormat:@"%@ = %@", resID, resource.name] forKey:resID];
            }
        }
    }
    // Sort the resources by id
    NSArray *resources = [allResources sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"resID" ascending:YES]]];
    for (id <ResKnifeResource> resource in resources) {
        [self.cases addObject:[NSString stringWithFormat:@"%@ = %d", resource.name, resource.resID]];
    }
}

- (NSFormatter *)formatter
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.hasThousandSeparators = NO;
    formatter.minimum = @(self.min);
    formatter.maximum = @(self.max);
    formatter.nilSymbol = @"\0";
    return formatter;
}

- (BOOL)matchesValue:(NSNumber *)value
{
    int val = [[self normalise:value] intValue];
    return val >= self.min && val <= self.max;
}

- (id)normalise:(id)value
{
    int val = [value intValue];
    return @((self.invert ? -val : val) - self.offset);
}

- (id)deNormalise:(id)value
{
    int val = [value intValue] + self.offset;
    return @(self.invert ? -val : val);
}

@end
