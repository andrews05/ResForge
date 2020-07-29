#import "ElementKRID.h"
#import "TemplateWindowController.h"
#import "RKSupport/RKSupport-Swift.h"
//#import "Template_Editor-Swift.h"

@implementation ElementKRID

- (void)configureGroupView:(NSTableCellView *)view
{
    if (self.currentSection) {
        view.textField.stringValue = [self.displayLabel stringByAppendingFormat:@": %@", [self.caseMap[self.value] displayLabel]];
    } else {
        view.textField.stringValue = [self.displayLabel stringByAppendingFormat:@": Error: No KEYB for resource id %@.", self.value];
    }
}

- (void)configure
{
    [self readCases];
    // Get the current resource id
    self.value = @(self.parentList.controller.resource.resID).stringValue;
    self.currentSection = self.keyedSections[self.value];
    if (self.currentSection) {
        [self.parentList insertElement:self.currentSection];
    } else {
        NSLog(@"No KEYB for resource id %@.", self.value);
    }
}

@end
