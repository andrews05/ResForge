#import "ElementKRID.h"
#import "ElementCASE.h"
#import "TemplateWindowController.h"

@implementation ElementKRID

- (NSView *)configureView:(NSOutlineView *)outlineView
{
    NSTextField *textField = [outlineView makeViewWithIdentifier:@"textData" owner:self];
    textField.editable = NO;
    [textField unbind:@"value"];
    textField.stringValue = self.currentSection.label ?: @"Error: No KEYB for this resource id";
    return textField;
}

- (void)configure
{
    [self readCases];
    // Get the current resource id
    NSString *resID = [@(self.parentList.controller.resource.resID) stringValue];
    self.currentSection = self.keyedSections[resID];
    if (self.currentSection) {
        [self.parentList insertElement:self.currentSection];
        self.currentSection.label = [self.caseMap[resID] symbol];
    } else {
        NSLog(@"No KEYB found for resource id %@.", resID);
    }
}

@end
