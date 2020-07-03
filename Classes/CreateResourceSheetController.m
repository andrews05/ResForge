#import "CreateResourceSheetController.h"
#import "ResourceDataSource.h"
#import "ResourceDocument.h"
#import "Resource.h"

@implementation CreateResourceSheetController

- (void)showCreateResourceSheet:(ResourceDocument *)sheetDoc withType:(NSString *)type andID:(NSNumber *)resID
{
    document = sheetDoc;
    if (type != nil) {
        typeView.stringValue = type;
        if (resID != nil) {
            resIDView.objectValue = resID;
            Resource *resource = [document.dataSource resourceOfType:GetOSTypeFromNSString(type) andID:(ResID)resID.intValue];
            createButton.enabled = resource == nil;
        } else {
            [self typeChanged:typeView];
        }
    }
    [document.mainWindow beginSheet:self.window completionHandler:nil];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    if (typeView.stringValue.length != 4 || !resIDView.stringValue.length) {
        createButton.enabled = NO;
    } else {
        // Check for conflict
        Resource *resource = [document.dataSource resourceOfType:GetOSTypeFromNSString(typeView.stringValue) andID:(ResID)resIDView.intValue];
        createButton.enabled = resource == nil;
    }
}

- (IBAction)typeChanged:(id)sender
{
    // Get a suitable id for this type
    resIDView.intValue = [document.dataSource uniqueIDForType:GetOSTypeFromNSString(typeView.stringValue)];
    createButton.enabled = YES;
}

- (IBAction)hideCreateResourceSheet:(id)sender
{
	if (sender == createButton) {
        Resource *resource = [Resource resourceOfType:GetOSTypeFromNSString(typeView.stringValue) andID:(ResID)resIDView.intValue withName:nameView.stringValue andAttributes:0];
		[document.undoManager beginUndoGrouping];
        [document.dataSource addResource:resource];
        if (nameView.stringValue.length == 0)
            [document.undoManager setActionName:NSLocalizedString(@"Create Resource", nil)];
        else
            [document.undoManager setActionName:[NSString stringWithFormat:NSLocalizedString(@"Create Resource '%@'", nil), nameView.stringValue]];
		[document.undoManager endUndoGrouping];
        [document openResourceUsingEditor:resource];
	}
    [self.window.sheetParent endSheet:self.window];
}

@end
