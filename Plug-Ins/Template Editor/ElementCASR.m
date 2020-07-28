#import "ElementCASR.h"
#import "ElementRSID.h"
#import "ElementRangeable.h"
#import "TemplateWindowController.h"

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
            scanner.charactersToBeSkipped = nil;
            if ([scanner scanString:@"," intoString:nil]) {
                if ([scanner scanInt:&_max]) {
                    valid = YES;
                } else {
                    _max = INT32_MAX;
                }
                scanner.charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                int normal;
                if ([scanner scanInt:&normal]) {
                    // If specified minimum is negative and no max was specified, assume inverted (from minimum down)
                    if (_min < 0 && _max == INT32_MAX) _max = -_max;
                    _invert = _min > _max;
                    _offset = (_invert ? -_min : _min) - normal;
                    _min = normal;
                    _max = (_invert ? -_max : _max) - _offset;
                }
                if ([scanner scanString:@"'" intoString:nil]) {
                    NSString *resType;
                    [scanner scanUpToString:@"'" intoString:&resType];
                    if ([scanner scanString:@"'" intoString:nil]) {
                        _resType = resType;
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
    if (self.min == self.max) {
        self.width = 0;
        return;
    }
    if (self.resType) {
        [self loadCases];
        [super configureView:view];
        [ElementRSID configureLinkButton:[view.subviews lastObject] forElement:self];
    } else {
        [super configureView:view];
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
    if (self.cases) return;
    // If a resType has been given this will become a combo box for resource selection
    self.width = self.parentElement.cases.count > 1 ? 180 : 240;
    self.cases = [NSMutableArray new];
    self.caseMap = [NSMutableDictionary new];
    // Find resources in all documents and sort by id
    id <ResKnifePluginManager> manager = (id <ResKnifePluginManager>)self.parentList.controller.window.delegate;
    NSArray *resources = [manager allResourcesOfType:self.resType currentDocumentOnly:false];
    resources = [resources sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    for (id <ResKnifeResource> resource in resources) {
        if (!resource.name.length) continue; // No point showing resources with no name
        if (resource.resID < self.min || resource.resID > self.max) continue;
        NSString *resID = @(resource.resID).stringValue;
        if (![self.caseMap objectForKey:resID]) {
            [self.cases addObject:[NSString stringWithFormat:@"%@ = %ld", resource.name, (long)resource.resID]];
            [self.caseMap setObject:[NSString stringWithFormat:@"%@ = %@", resID, resource.name] forKey:resID];
        }
    }
}

- (IBAction)openResource:(id)sender
{
    id <ResKnifePluginManager> manager = (id <ResKnifePluginManager>)self.parentList.controller.window.delegate;
    id <ResKnifeResource> resource = [manager findResourceOfType:self.resType id:(ResID)self.value currentDocumentOnly:false];
    if (resource) {
        [resource open];
    } else {
        NSBeep();
    }
}

- (NSFormatter *)formatter
{
    NSNumberFormatter *formatter = [self.parentElement.formatter copy];
    if (formatter.minimum.intValue < self.min)
        formatter.minimum = @(self.min);
    if (formatter.maximum.intValue > self.max)
        formatter.maximum = @(self.max);
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
