#import "ResourceDocument.h"
#import "RKSupport/RKSupport-Swift.h"
#import "ResKnife-Swift.h"
#import "../Categories/NSOutlineView-SelectedItems.h"
#include <copyfile.h>


NSString *RKResourcePboardType = @"com.nickshanks.resknife.resource";

@implementation ResourceDocument
@synthesize resources = _resources;
@synthesize creator = _creator;
@synthesize type = _type;

- (instancetype)init
{
    if (self = [super init])
        self.registry = [[PluginManager alloc] init:self];
    return self;
}

#pragma mark -
#pragma mark File Management

/*!
@method			readFromFile:ofType:
@abstract		Open the specified file and read its resources.
@description	Open the specified file and read its resources. This first tries to load the resources from the res fork, and failing that tries the data fork.
@author			Nicholas Shanks
@updated		2003-11-08 NGS:	Now handles opening user-selected forks.
*/

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    NSDictionary *attrs;
    NSNumber *totalSize;
    BOOL hasData, hasRsrc;
    NSURL *rsrcURL = [url URLByAppendingPathComponent:@"..namedfork/rsrc"];
    OpenPanelDelegate *openPanelDelegate = (OpenPanelDelegate *)NSDocumentController.sharedDocumentController;
    
    // Get the file info
    attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:outError];
    if (*outError) return NO;
    [url getResourceValue:&totalSize forKey:NSURLTotalFileSizeKey error:outError];
    if (*outError) return NO;
    
    _type = (OSType)[attrs[NSFileHFSTypeCode] integerValue];
    _creator = (OSType)[attrs[NSFileHFSCreatorCode] integerValue];
    hasData = [attrs[NSFileSize] integerValue] > 0;
    hasRsrc = [totalSize integerValue] - [attrs[NSFileSize] integerValue] > 0;
    
	// Find out which fork to parse
    _fork = [openPanelDelegate getSelectedFork];
    if (_fork) {
        // If fork was sepcified in open panel, try this fork only
        if ([_fork isEqualToString:@""] && hasData) {
            _resources = [ResourceFile readFromURL:url format:&_format error:outError];
        } else if ([_fork isEqualToString:@"rsrc"] && hasRsrc) {
            _resources = [ResourceFile readFromURL:rsrcURL format:&_format error:outError];
        } else {
            // Fork is empty
            _resources = [NSMutableArray new];
        }
    } else {
        // Try to open data fork
        if (hasData) {
            _fork = @"";
            _resources = [ResourceFile readFromURL:url format:&_format error:outError];
        }
        // If failed, try resource fork
        if (!_resources && hasRsrc) {
            _fork = @"rsrc";
            _resources = [ResourceFile readFromURL:rsrcURL format:&_format error:outError];
        }
        // If still failed, find an empty fork
        if (!_resources && !hasData) {
            _fork = @"";
            _resources = [NSMutableArray new];
        } else if (!_resources && !hasRsrc) {
            _fork = @"rsrc";
            _resources = [NSMutableArray new];
        }
    }
    
    if (_resources) {
        for (Resource *resource in _resources) {
            resource.document = self;
        }
        return YES;
    }
    
    return NO;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    if ([savePanel.nameFieldStringValue isEqualToString:self.defaultDraftName])
        savePanel.nameFieldStringValue = [self.defaultDraftName stringByAppendingPathExtension:@"rsrc"];
    return [super prepareSavePanel:savePanel];
}

- (BOOL)writeToURL:(NSURL *)url
            ofType:(NSString *)typeName
  forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)absoluteOriginalContentsURL
             error:(NSError **)outError
{
    if (saveOperation == NSSaveAsOperation) {
        // set fork according to typeName
        if ([typeName isEqualToString:@"ResourceMapRF"]) {
            _format = kFormatClassic;
            _fork = @"rsrc";
            // Set default type/creator for resource fork
            if (!_type && !_creator) {
                _type = 'rsrc';
                _creator = 'ResK';
            }
        } else {
            _format = [typeName isEqualToString:@"ResourceMapExtended"] ? kFormatExtended : kFormatClassic;
            _fork = @"";
            // Clear type/creator for data fork (filename extension should suffice)
            _type = 0;
            _creator = 0;
        }
    }
    
    // create file with attributes
    // bug: doesn't copy the finderinfo from the old file
    NSDictionary *attrs = nil;
    if (_type || _creator) {
        attrs = @{NSFileHFSTypeCode: @(_type), NSFileHFSCreatorCode: @(_creator)};
    }
    [[NSFileManager defaultManager] createFileAtPath:url.path contents:nil attributes:attrs];
   
    // write resources to file
    NSURL *writeUrl = [_fork isEqualToString:@"rsrc"] ? [url URLByAppendingPathComponent:@"..namedfork/rsrc"] : url;
    if (![ResourceFile writeResources:dataSource.resources toURL:writeUrl withFormat:self.format error:outError]) {
        return NO;
    }
    
    // copy the other fork
    if (saveOperation == NSSaveOperation) {
        if ([_fork isEqualToString:@""]) {
            url = [url URLByAppendingPathComponent:@"..namedfork/rsrc"];
            absoluteOriginalContentsURL = [absoluteOriginalContentsURL URLByAppendingPathComponent:@"..namedfork/rsrc"];
        }
        int fin = open(absoluteOriginalContentsURL.fileSystemRepresentation, O_RDONLY);
        if (fin != -1) {
            int fout = open(url.fileSystemRepresentation, O_WRONLY|O_CREAT);
            int err = copyfile(absoluteOriginalContentsURL.fileSystemRepresentation, url.fileSystemRepresentation, NULL, COPYFILE_DATA);
            close(fout);
            close(fin);
            if (err) return NO;
        }
    }
	
	// update info window
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentInfoDidChangeNotification" object:self];
	
	return YES;
}

#pragma mark -
#pragma mark Export to File

- (IBAction)exportResources:(id)sender
{
    NSArray *selected = [dataSource allSelectedResources];
    if (selected.count > 1) {
		NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.allowsMultipleSelection = NO;
        panel.canChooseDirectories = YES;
        panel.canChooseFiles = NO;
        panel.prompt = @"Choose";
        panel.message = @"Choose where to export the selected resources";
		[panel beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                for (Resource *resource in selected) {
                    NSString *filename = [self filenameForExport:resource];
                    [self exportResource:resource toURL:[panel.URL URLByAppendingPathComponent:filename]];
                }
            }
		}];
    } else if (selected.count == 1) {
        Resource *resource = selected.firstObject;
        NSSavePanel *panel = [NSSavePanel savePanel];
        NSString *filename = [self filenameForExport:resource];
        panel.nameFieldStringValue = filename;
        //panel.allowedFileTypes = @[filename.pathExtension];
        [panel beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                [self exportResource:resource toURL:panel.URL];
            }
        }];
	}
}

- (NSString *)filenameForExport:(Resource *)resource
{
    NSString *resType = resource.type;
    Class editorClass = [PluginManager editorFor:resType];
    NSString *extension;
    
    // ask for file extension
    if ([editorClass respondsToSelector:@selector(filenameExtensionFor:)]) {
        extension = [editorClass filenameExtensionFor:resource.type];
    } else {
        extension = [[resType lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    NSString *filename = [resource.name stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    if ([filename isEqualToString:@""]) {
        filename = [NSString stringWithFormat:@"%@ %ld", resType, (long)resource.id];
    }
    NSString *fullname = [filename stringByAppendingPathExtension:extension];
    
    unsigned int i = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:fullname]) {
        fullname = [filename stringByAppendingFormat:@" %d", i++];
        fullname = [fullname stringByAppendingPathExtension:extension];
    }
    return fullname;
}

- (void)exportResource:(Resource *)resource toURL:(NSURL *)url
{
    Class editorClass = [PluginManager editorFor:resource.type];
    if ([editorClass respondsToSelector:@selector(exportResource:toURL:)]) {
        [editorClass exportResource:resource toURL:url];
    } else {
        [resource.data writeToURL:url atomically:YES];
    }
}

#pragma mark -
#pragma mark Window Management

- (NSString *)windowNibName
{
    return @"ResourceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
    [dataSource addWithResources:_resources];
	[super windowControllerDidLoadNib:controller];
	[outlineView registerForDraggedTypes:@[RKResourcePboardType]];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
    if ([self.registry closeAll]) {
        [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	NSInteger selectedRows = [outlineView numberOfSelectedRows];
    Resource *resource = nil;
    if ([[outlineView selectedItem] isKindOfClass:[Resource class]]) {
        resource = (Resource *)[outlineView selectedItem];
    }
	
	// file menu
	if([item action] == @selector(saveDocument:))			return [self isDocumentEdited];
	
	// edit menu
	else if([item action] == @selector(delete:))			return selectedRows > 0;
	else if([item action] == @selector(selectAll:))			return [outlineView numberOfRows] > 0;
	else if([item action] == @selector(deselectAll:))		return selectedRows > 0;
	
	// resource menu
	else if([item action] == @selector(openResources:))						return selectedRows > 0;
	else if([item action] == @selector(openResourcesInTemplate:))			return selectedRows > 0;
	//else if([item action] == @selector(openResourcesWithOtherTemplate:))	return selectedRows > 0;
	else if([item action] == @selector(openResourcesAsHex:))				return selectedRows > 0;
    else if([item action] == @selector(exportResources:))                   return selectedRows > 0;
	//else if([item action] == @selector(revertResourceToSaved:))	return selectedRows == 1 && [resource isDirty];
	else return [super validateMenuItem:item];
}

#pragma mark -
#pragma mark Toolbar Management

static NSString *RKCreateItemIdentifier		= @"com.nickshanks.resknife.toolbar.create";
static NSString *RKDeleteItemIdentifier		= @"com.nickshanks.resknife.toolbar.delete";
static NSString *RKEditItemIdentifier		= @"com.nickshanks.resknife.toolbar.edit";
static NSString *RKEditHexItemIdentifier	= @"com.nickshanks.resknife.toolbar.edithex";
static NSString *RKSaveItemIdentifier		= @"com.nickshanks.resknife.toolbar.save";
static NSString *RKShowInfoItemIdentifier	= @"com.nickshanks.resknife.toolbar.showinfo";
static NSString *RKExportItemIdentifier		= @"com.nickshanks.resknife.toolbar.export";
static NSString *RKViewItemIdentifier		= @"com.nickshanks.resknife.toolbar.view";

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	BOOL valid = NO;
	NSInteger selectedRows = [outlineView numberOfSelectedRows];
	NSString *identifier = [item itemIdentifier];
	
	if([identifier isEqualToString:RKCreateItemIdentifier])
		valid = YES;
	else if([identifier isEqualToString:RKDeleteItemIdentifier])
		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKEditItemIdentifier])
		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKEditHexItemIdentifier])
		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKExportItemIdentifier])
		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKSaveItemIdentifier])
		valid = [self isDocumentEdited];
	else if([identifier isEqualToString:NSToolbarPrintItemIdentifier])
		valid = YES;
	
	return valid;
}

#pragma mark -
#pragma mark Document Management

- (IBAction)showCreateResourceSheet:(id)sender
{
    if (!sheetController) {
		sheetController = [[CreateResourceController alloc] initWithWindowNibName:@"CreateResourceSheet"];
    }
	
    // Pass type of currently selected item
    id item = outlineView.selectedItem;
    NSString *type;
    if ([item isKindOfClass:Resource.class]) {
        type = [(Resource *)item type];
    } else if ([item isKindOfClass:NSString.class]) {
        type = item;
    }
    [sheetController showSheetIn:self type:type];
}

- (IBAction)showSelectTemplateSheet:(id)sender
{
	// bug: ResourceDocument allocs a sheet controller, but it's never disposed of
//	SelectTemplateSheetController *sheetController = [[CreateResourceSheetController alloc] initWithWindowNibName:@"SelectTemplateSheet"];
//	[sheetController showSelectTemplateSheet:self];
}

- (IBAction)openResources:(id)sender
{
	// ignore double-clicks in table header
    if (sender == outlineView && outlineView.clickedRow == -1)
		return;
	
    NSEvent *event = NSApp.currentEvent;
    if (event.type == NSLeftMouseUp && (event.modifierFlags & NSDeviceIndependentModifierFlagsMask & NSAlternateKeyMask) != 0) {
		[self openResourcesAsHex:sender];
    } else {
        for (Resource *resource in outlineView.selectedItems) {
            if ([resource isKindOfClass:Resource.class] ) {
                [self.registry openWithResource:resource using:nil template:nil];
            } else {
                [outlineView expandItem:resource];
            }
		}
	}
}

- (IBAction)openResourcesInTemplate:(id)sender
{
	// opens the resource in its default template
    Class editorClass = [PluginManager editorFor:@"Template Editor"];
	for (Resource *resource in outlineView.selectedItems) {
        if ([resource isKindOfClass: Resource.class]) {
            [self.registry openWithResource:resource using:editorClass template:nil];
        }
	}
}

- (IBAction)openResourcesAsHex:(id)sender
{
    Class editorClass = [PluginManager editorFor:@"Hexadecimal Editor"];
	for (Resource *resource in outlineView.selectedItems) {
        if ([resource isKindOfClass: Resource.class]) {
            [self.registry openWithResource:resource using:editorClass template:nil];
        }
	}
}

#pragma mark -
#pragma mark Edit Operations

- (IBAction)cut:(id)sender
{
	[self copy:sender];
	[self delete:sender];
}

- (IBAction)copy:(id)sender
{
	#pragma unused(sender)
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	[pb declareTypes:@[RKResourcePboardType] owner:self];
    [pb writeObjects:[dataSource allSelectedResources]];
}

- (IBAction)paste:(id)sender
{
	#pragma unused(sender)
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [self pasteResources:[pb readObjectsForClasses:@[Resource.class] options:nil]];
}

- (void)pasteResources:(NSArray *)pastedResources
{
	Resource *resource;
	NSEnumerator *enumerator = [pastedResources objectEnumerator];
	while(resource = (Resource *) [enumerator nextObject])
	{
		// check resource type/ID is available
        if([dataSource findResourceWithType:resource.type id:resource.id] == nil)
		{
			// resource slot is available, paste this one in
			[dataSource add:resource];
		}
		else
		{
			// resource slot is ocupied, ask user what to do
			NSArray *remainingResources = [enumerator allObjects];
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Paste Error";
            alert.informativeText = [NSString stringWithFormat:@"There already exists a resource of type %@ with ID %ld. Do you wish to assign the pasted resource a unique ID, overwrite the existing resource, or skip pasting of this resource?", resource.type, (long)resource.id];
			[alert addButtonWithTitle:@"Unique ID"];
			[alert addButtonWithTitle:@"Overwrite"];
			[alert addButtonWithTitle:@"Skip"];
			[alert beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse returnCode) {
				if(returnCode == NSAlertFirstButtonReturn)	// unique ID
				{
                    resource.id = [self.dataSource uniqueIDFor:resource.type starting:resource.id];
                    //Resource *newResource = [[Resource alloc] initWithType:resource.type id:[self.dataSource uniqueIDForType:resource.type] name:resource.name attributes:resource.attributes data:resource.data];
					[self.dataSource add:resource];
				}
				else if(returnCode == NSAlertSecondButtonReturn)				// overwrite
				{
                    [self.dataSource remove:[self.dataSource findResourceWithType:resource.type id:resource.id]];
					[self.dataSource add:resource];
				}
				//else if(NSAlertAlternateReturn)			// skip
				
				// continue paste
				[self pasteResources:remainingResources];
			}];
		}
	}
}

- (IBAction)delete:(id)sender
{
#pragma unused(sender)
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"DeleteResourceWarning"])
	{
		NSAlert *alert = [NSAlert new];
		alert.messageText = @"Delete Resource";
		alert.informativeText = @"Are you sure you want to delete the selected resources?";
		[alert addButtonWithTitle:@"Delete"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.mainWindow completionHandler:^(NSModalResponse returnCode) {
			switch (returnCode) {
				case NSAlertFirstButtonReturn:
					[self deleteSelectedResources];
					break;
				
				case NSModalResponseCancel:		// cancel
					break;
			}
		}];
	}
	else [self deleteSelectedResources];
}

- (void)deleteSelectedResources
{
	Resource *resource;
	NSEnumerator *enumerator;
    NSArray *selected = [dataSource allSelectedResources];
	
	// enumerate through array and delete resources
	[[self undoManager] beginUndoGrouping];
	enumerator = [selected reverseObjectEnumerator];		// reverse so an undo will replace items in original order
	while(resource = [enumerator nextObject])
	{
		[dataSource remove:resource];
		if([[resource name] length] == 0)
			[[self undoManager] setActionName:NSLocalizedString(@"Delete Resource", nil)];
		else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Delete Resource '%@'", nil), [resource name]]];
	}
	[[self undoManager] endUndoGrouping];
	
	// generalise undo name if more than one was deleted
	if([selected count] > 1)
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Resources", nil)];
	
	// deselect resources (otherwise other resources move into selected rows!)
	[outlineView deselectAll:self];
}

#pragma mark -
#pragma mark Accessors

- (NSWindow *)mainWindow
{
	return mainWindow;
}

- (ResourceDataSource *)dataSource
{
	return dataSource;
}

- (NSOutlineView *)outlineView
{
	return outlineView;
}

- (OSType)creator
{
	return _creator;
}

- (OSType)type
{
	return _type;
}

- (void)setCreator:(OSType)newCreator
{
	if (newCreator != _creator) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentInfoWillChangeNotification" object:self];
        [(ResourceDocument *)[[self undoManager] prepareWithInvocationTarget:self] setCreator:_creator];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Creator Code", nil)];
		_creator = newCreator;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentInfoDidChangeNotification" object:self];
	}
}

- (void)setType:(OSType)newType
{
	if (newType != _type) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentInfoWillChangeNotification" object:self];
        [(ResourceDocument *)[[self undoManager] prepareWithInvocationTarget:self] setType:_type];
		[[self undoManager] setActionName:NSLocalizedString(@"Change File Type", nil)];
		_type = newType;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentInfoDidChangeNotification" object:self];
	}
}

- (IBAction)changeView:(id)sender
{
	
}

@end
