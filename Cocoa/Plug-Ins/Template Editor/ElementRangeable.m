#import "ElementRangeable.h"
#import "TemplateWindowController.h"

@implementation ElementRangeable

- (void)configureView:(NSView *)view
{
    if (!self.isRanged) {
        [super configureView:view];
        return;
    }
    if (!self.currentCase)
        [self loadValue];
    // Only show the select menu if there are multiple options
    if (self.cases.count > 1) {
        NSRect orig = view.frame;
        NSRect frame = view.frame;
        frame.size.width = 180-1;
        NSPopUpButton *select = [[NSPopUpButton alloc] initWithFrame:frame];
        select.target = self;
        select.action = @selector(caseChanged:);
        [select bind:@"content" toObject:self withKeyPath:@"cases" options:nil];
        [select bind:@"selectedObject" toObject:self withKeyPath:@"currentCase" options:nil];
        [view addSubview:select];
        frame.origin.x = 180;
        view.frame = frame;
        [self.currentCase configureView:view];
        view.frame = orig;
    } else {
        [self.currentCase configureView:view];
    }
}

- (IBAction)caseChanged:(id)sender
{
    if (self.displayValue < self.currentCase.min) {
        self.displayValue = self.currentCase.min;
    } else if (self.displayValue > self.currentCase.max) {
        self.displayValue = self.currentCase.max;
    } else {
        self.displayValue = self.displayValue; // Still need to trigger the transformer
    }
    [self.parentList.controller.dataList reloadItem:self];
    [self.parentList.controller itemValueUpdated:sender];
}

- (void)configure
{
    // Read CASR elements
    ElementCASR *element = [self.parentList peek:1];
    if (element.class == ElementCASR.class) {
        self.isRanged = YES;
        self.cases = [NSMutableArray new];
        while (element.class == ElementCASR.class) {
            [self.cases addObject:[self.parentList pop]];
            element.parentList = self.parentList; // Required for the element to trigger itemValueUpdated
            element.parentElement = self;
            element.width = self.width;
            element = [self.parentList peek:1];
        }
    } else {
        [super configure];
    }
}

- (void)loadValue
{
    self.currentCase = self.cases[0]; // Default in case no match found
    NSNumber *value = [self valueForKey:@"value"];
    for (ElementCASR *element in self.cases) {
        if ([element matchesValue:value]) {
            self.currentCase = element;
            break;
        }
    }
    self.displayValue = [[self.currentCase normalise:value] intValue];
    [self bind:@"value" toObject:self withKeyPath:@"displayValue" options:@{NSValueTransformerBindingOption:self}];
    
}

- (id)transformedValue:(id)value
{
    if (!self.isRanged)
        return [super transformedValue:value];
    return [self.currentCase deNormalise:value];
}

- (id)reverseTransformedValue:(id)value
{
    if (!self.isRanged)
        return [super reverseTransformedValue:value];
    return [self.currentCase normalise:value];
}

@end
