#import "ElementRSID.h"
#import "ElementCASE.h"
#import "TemplateWindowController.h"
#import "RKSupport/RKSupport-Swift.h"
//#import "Template_Editor-Swift.h"
/*
 * RSID allows selecting a resource id of a given type
 * The parameters are specified in the label
 * Resource type is a 4-char code enclosed in single (or smart) quotes
 * Offset is a number followed by a + (a value of zero refers to this id)
 * Limit is a number immediately following the +
 * If limit is specified the list will only show resources between offset and offset+limit
 * E.g. "Extension scope info 'scop' -27136 +2" will show 'scop' resources between -27136 and -27134
 * If the resource type cannot be determined from the label, it will look for a preceding TNAM element to determine the type
 */
@implementation ElementRSID
@synthesize resType = _resType;

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        // Determine parameters from label
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:.*[‘'](.{4})['’])?(?:.*?(-?[0-9]+) *[+]([0-9]+)?)?" options:0 error:nil];
        NSTextCheckingResult *result = [regex firstMatchInString:l options:0 range:NSMakeRange(0, l.length)];
        NSRange r = [result rangeAtIndex:1];
        if (r.location != NSNotFound) {
            _resType = [l substringWithRange:[result rangeAtIndex:1]];
        }
        r = [result rangeAtIndex:2];
        if (r.location != NSNotFound) {
            _offset = [[l substringWithRange:r] intValue];
            r = [result rangeAtIndex:3];
            if (r.location != NSNotFound) {
                _max = _offset + [[l substringWithRange:r] intValue];
            }
        }
    }
    return self;
}

- (NSString *)resType
{
    return _resType;
}

- (void)setResType:(NSString *)resType
{
    _resType = resType;
    [self loadCases];
}

- (void)configureView:(NSView *)view
{
    [super configureView:view];
    [ElementRSID configureLinkButton:[view.subviews lastObject] forElement:self];
}

+ (void)configureLinkButton:(NSComboBox *)comboBox forElement:(Element *)element
{
    // Add a link button at the end of the combo box to open the referenced resource
    [(NTInsensitiveComboBoxCell *)comboBox.cell setRightMargin:15];
    NSRect frame = comboBox.frame;
    frame.origin.x += frame.size.width-35;
    frame.origin.y += 7;
    frame.size.width = frame.size.height = 12;
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.bordered = NO;
    button.bezelStyle = NSBezelStyleInline;
    button.image = [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
    button.imageScaling = NSImageScaleProportionallyDown;
    button.target = element;
    button.action = @selector(openResource:);
    [comboBox.superview addSubview:button];
}

- (void)configure
{
    if (!self.resType) {
        // See if we can bind to a preceding TNAM field
        Element *tnam = [self.parentList previousOfType:@"TNAM"];
        if (!tnam) {
            NSLog(@"Could not determine resource type for RSID.");
            [super configure];
            return;
        }
        [self bind:@"resType" toObject:tnam withKeyPath:@"tnam" options:nil];
    }
    self.width = 240;
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
        NSString *option = [NSString stringWithFormat:@"%@ = %@", element.displayLabel, element.value];
        NSString *display = [NSString stringWithFormat:@"%@ = %@", element.value, element.displayLabel];
        [cases addObject:option];
        [self.caseMap setObject:display forKey:element.value];
    }
    if (self.resType) {
        // Find resources in all documents and sort by id
        id <ResKnifePluginManager> manager = self.parentList.controller.resource.manager;
        NSArray *resources = [manager allResourcesOfType:self.resType currentDocumentOnly:false];
        resources = [resources sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        for (Resource *resource in resources) {
            if (!resource.name.length) continue; // No point showing resources with no name
            if (self.max && (resource.id < self.offset || resource.id > self.max)) continue;
            NSString *resID = @(resource.id-self.offset).stringValue;
            if (![self.caseMap valueForKey:resID]) {
                NSString *idDisplay = [self resIDDisplay:resID];
                [cases addObject:[NSString stringWithFormat:@"%@ = %@", resource.name, idDisplay]];
                [self.caseMap setValue:[NSString stringWithFormat:@"%@ = %@", idDisplay, resource.name] forKey:resID];
            }
        }
    }
    self.cases = cases; // This triggers the combo box refresh
}

- (IBAction)openResource:(id)sender
{
    id <ResKnifePluginManager> manager = self.parentList.controller.resource.manager;
    Resource *resource = [manager findResourceOfType:self.resType id:(self.value+self.offset) currentDocumentOnly:false];
    if (resource) {
        [manager openWithResource:resource using:nil template:nil];
    } else {
        NSBeep();
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
