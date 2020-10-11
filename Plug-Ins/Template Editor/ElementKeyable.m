#import "ElementKeyable.h"
#import "ElementCASE.h"
#import "Template_Editor-Swift.h"

// Abstract Element subclass that handles keyed sections
@implementation ElementKeyable

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.isKeyed = [t characterAtIndex:0] == 'K';
        if (self.isKeyed) self.width = 240;
    }
    return self;
}

- (void)configureView:(NSView *)view
{
    if (!self.isKeyed) {
        [super configureView:view];
        return;
    }
    NSRect frame = view.frame;
    frame.size.width = self.width-1;
    frame.size.height = 23;
    frame.origin.y = -1;
    NSPopUpButton *keySelect = [[NSPopUpButton alloc] initWithFrame:frame];
    keySelect.target = self;
    keySelect.action = @selector(keyChanged:);
    [keySelect bind:@"content" toObject:self withKeyPath:@"cases" options:nil];
    [keySelect bind:@"selectedObject" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self,
                                                                                   NSValidatesImmediatelyBindingOption:@(self.formatter != nil)}];
    [view addSubview:keySelect];
}

- (IBAction)keyChanged:(NSPopUpButton *)sender
{
    ElementKEYB *oldSection = [self setCase:self.cases[sender.indexOfSelectedItem]];
    if (oldSection) {
        // Check if the section sizes match and attempt to copy the data
        UInt32 currentSize = [oldSection.subElements sizeOnDisk];
        UInt32 newSize = [self.currentSection.subElements sizeOnDisk];
        if (currentSize == newSize && currentSize > 0) {
            NSMutableData *data = [NSMutableData dataWithLength:currentSize];
            ResourceStream *stream = [ResourceStream streamWithData:data];
            [oldSection writeDataTo:stream];
            stream = [ResourceStream streamWithData:data];
            [self.currentSection readDataFrom:stream];
            
        }
        NSOutlineView *outlineView = self.parentList.controller.dataList;
        // Item isn't necessarily self
        [outlineView reloadItem:[outlineView itemAtRow:[outlineView rowForView:sender]] reloadChildren:YES];
    }
    [self.parentList.controller itemValueUpdated:sender];
}

- (ElementKEYB *)setCase:(ElementCASE *)element
{
    ElementKEYB *newSection = element.class == ElementCASE.class ? self.keyedSections[element.value] : nil;
    if (newSection == self.currentSection)
        return nil;
    ElementKEYB *oldSection = self.currentSection;
    [self.parentList remove:oldSection];
    self.currentSection = newSection;
    if (newSection)
        [self.parentList insert:newSection after:self];
    return oldSection;
}

- (void)readCases
{
    self.cases = [NSMutableArray new];
    self.caseMap = [NSMutableDictionary new];
    self.keyedSections = [NSMutableDictionary new];
    __kindof Element *element = [self.parentList peek:1];
    // Read CASEs
    while (element.class == ElementCASE.class) {
        [self.parentList pop];
        [self.cases addObject:element];
        [self.caseMap setObject:element forKey:[element value]];
        element = [self.parentList peek:1];
    }
    // Read KEYBs
    while (element.class == ElementKEYB.class) {
        [self.parentList pop];
        element.parentList = self.parentList;
        [element configure];
        // Allow one KEYB to be used for multiple cases
        NSArray *vals = [element.label componentsSeparatedByString:@","];
        for (NSString *value in vals) {
            ElementCASE *caseEl = self.caseMap[value];
            if (caseEl) {
                [self.keyedSections setObject:element forKey:caseEl.value];
            } else {
                NSLog(@"No corresponding CASE for KEYB '%@'.", value);
            }
        }
        element = [self.parentList peek:1];
    }
    if (self.keyedSections.count != self.cases.count) {
        NSLog(@"Not all CASEs have corresponding KEYB sections.");
    }
}

- (void)configure
{
    if (!self.isKeyed) {
        [super configure];
        return;
    }
    
    [self readCases];

    // Set initial value to first case
    id value = [(ElementCASE *)self.cases[0] value];
    self.currentSection = self.keyedSections[value];
    [self validateValue:&value forKey:@"value" error:nil];
    [self setValue:value forKey:@"value"];
    [self.parentList insert:self.currentSection];
    
    // Use KVO to observe value change when data is first read
    // This saves us adding any key logic to the concrete element subclasses
    [self addObserver:self forKeyPath:@"value" options:0 context:nil];
}

- (BOOL)hasSubElements
{
    return YES;
}

- (NSInteger)subElementCount
{
    return self.currentSection.subElementCount;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
    return [self.currentSection subElementAtIndex:n];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    // In theory this will only run when the key is first read from the resource
    // Make sure we load the correct section here so that we continue reading the resource into that section
    [self setCase:[self transformedValue:[self valueForKey:@"value"]]];
    [self removeObserver:self forKeyPath:@"value"];
}

- (id)reverseTransformedValue:(id)value
{
    if (!self.isKeyed)
        return [super reverseTransformedValue:value];
    // Value is a CASE element - get the string value
    return [(ElementCASE *)value value];
}

@end
