#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "Resource.h"
#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"
#import "OutlineViewDelegate.h"
#import "InfoWindowController.h"
#import "PrefsController.h"
#import "CreateResourceSheetController.h"
#import "../Categories/NGSCategories.h"
#import "../Categories/NSOutlineView-SelectedItems.h"
#include "libGraphite/rsrc/file.hpp"
#include <fcntl.h>
#include <copyfile.h>

#import "../Plug-Ins/ResKnifePluginProtocol.h"
#import "RKEditorRegistry.h"


NSString *DocumentInfoWillChangeNotification = @"DocumentInfoWillChangeNotification";
NSString *DocumentInfoDidChangeNotification = @"DocumentInfoDidChangeNotification";
extern NSString *RKResourcePboardType;

@implementation ResourceDocument
@synthesize resources = _resources;
@synthesize creator = _creator;
@synthesize type = _type;

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
    OpenPanelDelegate *openPanelDelegate = [(ApplicationDelegate *)[NSApp delegate] openPanelDelegate];
    
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
            _resources = [ResourceDocument readResourceMap:url];
        } else if ([_fork isEqualToString:@"rsrc"] && hasRsrc) {
            _resources = [ResourceDocument readResourceMap:rsrcURL];
        } else {
            // Fork is empty
            _resources = [NSMutableArray new];
        }
    } else {
        // Try to open data fork
        if (hasData) {
            _fork = @"";
            _resources = [ResourceDocument readResourceMap:url];
        }
        // If failed, try resource fork
        if (!_resources && hasRsrc) {
            _fork = @"rsrc";
            _resources = [ResourceDocument readResourceMap:rsrcURL];
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
    
    if (!_resources) {
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
        return NO;
    }
	
	return YES;
}

+ (NSMutableArray *)readResourceMap:(NSURL *)url
{
    graphite::rsrc::file gFile;
    try {
        gFile = graphite::rsrc::file(url.fileSystemRepresentation);
    } catch (const std::exception& e) {
        return nil;
    }
    NSMutableArray* resources = [NSMutableArray new];
    for (auto type : gFile.types()) {
        for (auto resource : type->resources()) {
            // create the resource & add it to the array
            NSString    *name       = [NSString stringWithUTF8String:resource->name().c_str()];
            NSString    *resType    = [NSString stringWithUTF8String:type->code().c_str()];
            NSData      *data       = [NSData dataWithBytes:resource->data()->get()->data()+resource->data()->start() length:resource->data()->size()];
            Resource *r = [Resource resourceOfType:GetOSTypeFromNSString(resType) andID:(SInt16)resource->id() withName:name andAttributes:0 data:data];
            [resources addObject:r]; // array retains resource
        }
    }
    return resources;
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
        if ([typeName isEqualToString:@"ResourceMap"]) {
            _fork = @"";
            // Clear type/creator for data fork (filename extension should suffice)
            _type = 0;
            _creator = 0;
        } else if ([typeName isEqualToString:@"ResourceMapRF"]) {
            _fork = @"rsrc";
            // Set default type/creator for resource fork
            if (!_type && !_creator) {
                _type = 'rsrc';
                _creator = 'ResK';
            }
        }
    }
    
    // write resources to file
    NSURL *writeUrl = [_fork isEqualToString:@"rsrc"] ? [url URLByAppendingPathComponent:@"..namedfork/rsrc"] : url;
    if (![self writeResourceMap:writeUrl])
        return NO;
    
    // set creator & type
    if (_type || _creator) {
        // bug: doesn't copy the remaining finderinfo from the old file
        NSDictionary *attrs = @{NSFileHFSTypeCode: @(_type), NSFileHFSCreatorCode: @(_creator)};
        [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:url.path error:outError];
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
	[[InfoWindowController sharedInfoWindowController] updateInfoWindow];
	
	return YES;
}

- (BOOL)writeResourceMap:(NSURL *)url
{
    graphite::rsrc::file gFile = graphite::rsrc::file();
    for (Resource* resource in [dataSource resources]) {
        std::string name([resource.name UTF8String]);
        std::string resType([GetNSStringFromOSType(resource.type) UTF8String]);
        std::vector<char> buffer((char *)resource.data.bytes, (char *)resource.data.bytes+resource.size);
        graphite::data::data data(std::make_shared<std::vector<char>>(buffer), resource.size);
        gFile.add_resource(resType, resource.resID, name, std::make_shared<graphite::data::data>(data));
    }
    try {
        gFile.write(url.fileSystemRepresentation);
    } catch (const std::exception& e) {
        return NO;
    }
    return YES;
}

#pragma mark -
#pragma mark Export to File

/*!
@method		exportResources:
@author		Nicholas Shanks
@created	24 October 2003
*/

- (IBAction)exportResources:(id)sender
{
	if ([outlineView numberOfSelectedRows] > 1)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setAllowsMultipleSelection:NO];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		//[panel beginSheetForDirectory:nil file:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(folderChoosePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
		[panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
			[self folderChoosePanelDidEnd:panel returnCode:result contextInfo:nil];
		}];
	}
	else
	{
		[self exportResource:[outlineView selectedItem]];
	}
}

/*!
@method		exportResource:
@author		Uli Kusterer
@updated	2003-10-24 NGS: moved IBAction target to exportResources: above, renamed this method
*/

#warning Note to Uli: how about changing the selector that the plug should implement to -(BOOL)dataForFileExport:(NSData **)fileData ofType:(NSString **)fileType. This is basically a concatenation of the two methods you came up with, but can allow the host app to specify a preferred file type (e.g. EPS) to a plug (say the PICT plug) and if the plug can't return data in that format, that's OK, it just returns the fileType of the associated data anyway. I would also recommend adding a plug method called something like availableTypesForFileExport: which returns a dictionary of file extensions and human-readable names (names should be overridden by system default names for that extension if present) that the plug can export data into, useful for say populating a pop-up menu in the export dialog.

- (void)exportResource:(Resource *)resource
{
	Class		editorClass = [[RKEditorRegistry defaultRegistry] editorForType:GetNSStringFromOSType([resource type])];
	NSData		*exportData = [resource data];
	NSString	*extension = [[GetNSStringFromOSType([resource type]) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// basic overrides for file name extensions (assume no plug-ins installed)
	NSString *newExtension;
	NSDictionary *adjustments = @{@"sfnt": @"ttf"};
	if((newExtension = adjustments[extension]))
		extension = newExtension;
	
	// ask for data
	if([editorClass respondsToSelector:@selector(dataForFileExport:)])
		exportData = [editorClass dataForFileExport:resource];
	
	// ask for file extension
	if([editorClass respondsToSelector:@selector(filenameExtensionForFileExport:)])
		extension = [editorClass filenameExtensionForFileExport:resource];
	
	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *filename = ([resource name] && ![[resource name] isEqualToString:@""]) ? [resource name] : NSLocalizedString(@"Untitled Resource",nil);
	filename = [filename stringByAppendingPathExtension:extension];
	[panel setNameFieldStringValue:filename];
	//[panel beginSheetForDirectory:nil file:filename modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:) contextInfo:[exportData retain]];
	[panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
		if(result == NSOKButton)
			[exportData writeToURL:[panel URL] atomically:YES];
	}];
}

- (void)folderChoosePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSOKButton)
	{
		unsigned int i = 1;
		NSString *filename, *extension;
		NSDictionary *adjustments = @{@"sfnt": @"ttf", @"PNGf": @"png"};
		for (Resource *resource in [dataSource allResourcesForItems:[outlineView selectedItems]]) {
			NSString *NSResType = GetNSStringFromOSType([resource type]);

			Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:GetNSStringFromOSType([resource type])];
			NSData *exportData = [resource data];
			extension = [[NSResType lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			// basic overrides for file name extensions (assume no plug-ins installed)
			if(adjustments[NSResType])
				extension = adjustments[NSResType];
			
			// ask for data
			if([editorClass respondsToSelector:@selector(dataForFileExport:)])
				exportData = [editorClass dataForFileExport:resource];
			
			// ask for file extension
			if([editorClass respondsToSelector:@selector(filenameExtensionForFileExport:)])
				extension = [editorClass filenameExtensionForFileExport:resource];
			
			filename = [resource name];
			if (!filename || [filename isEqualToString:@""])
			{
				filename = [NSString stringWithFormat:NSLocalizedString(@"Untitled '%@' Resource %d",nil), [resource type], i++];
				filename = [filename stringByAppendingPathExtension:extension];
			}
			else
			{
				unsigned int j = 1;
				NSString *tempname = [filename stringByAppendingPathExtension:extension];
				while ([[NSFileManager defaultManager] fileExistsAtPath:tempname])
				{
					tempname = [filename stringByAppendingFormat:@" (%d)", j++];
					tempname = [tempname stringByAppendingPathExtension:extension];
				}
				filename = tempname;
			}
			NSURL *url = [[sheet URL] URLByAppendingPathComponent:filename];
			[exportData writeToURL:url atomically:YES];
		}
	}
}

#pragma mark -
#pragma mark Window Management

- (NSString *)windowNibName
{
    return @"ResourceDocument";
}

/*	This is not used, just here for reference in case I need it in the future

- (void)makeWindowControllers
{
	ResourceWindowController *resourceController = [[ResourceWindowController allocWithZone:[self zone]] initWithWindowNibName:@"ResourceDocument"];
    [self addWindowController:resourceController];
}*/

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
	[super windowControllerDidLoadNib:controller];
	
	{	// set up first column in outline view to display images as well as text
		ResourceNameCell *resourceNameCell = [[ResourceNameCell alloc] init];
		[resourceNameCell setEditable:YES];
		[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:resourceNameCell];
		// NSLog(@"Changed data cell");
	}
	
	[outlineView setVerticalMotionCanBeginDrag:YES];
	[outlineView registerForDraggedTypes:@[RKResourcePboardType, NSStringPboardType, NSFilenamesPboardType]];
	
	// register for resource will change notifications (for undo management)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameWillChange:) name:ResourceNameWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceIDWillChange:) name:ResourceIDWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeWillChange:) name:ResourceTypeWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesWillChange:) name:ResourceAttributesWillChangeNotification object:nil];
	
    [dataSource addResources:_resources];
}

- (void)printDocumentWithSettings:(NSDictionary *)printSettings
                   showPrintPanel:(BOOL)showPrintPanel
                         delegate:(id)delegate
                 didPrintSelector:(SEL)didPrintSelector
                      contextInfo:(void *)contextInfo
{
	NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:[mainWindow contentView]];
	[printOperation runOperationModalForWindow:mainWindow delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:NULL];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo
{
	if(!success) NSLog(@"Printing Failed!");
}

- (BOOL)keepBackupFile
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kPreserveBackups];
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
//    else if([item action] == @selector(exportResourceToImageFile:))
//    {
//        if(selectedRows < 1) return NO;
//        Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:GetNSStringFromOSType([resource type])];
//        return [editorClass respondsToSelector:@selector(imageForImageFileExport:)];
//    }
	else if([item action] == @selector(playSound:))				return selectedRows == 1 && [resource type] == 'snd ';
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
	// bug: ResourceDocument allocs a sheet controller, but it's never disposed of
	
	if (!sheetController)
		sheetController = [[CreateResourceSheetController alloc] initWithWindowNibName:@"CreateResourceSheet"];
	
	[sheetController showCreateResourceSheet:self];
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
	if(sender == outlineView && [outlineView clickedRow] == -1)
		return;
	
	
	NSEvent *event = [NSApp currentEvent];
	if ([event type] == NSLeftMouseUp && (([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) & NSAlternateKeyMask) != 0)
		[self openResourcesAsHex:sender];
	else {
		for (Resource *resource in [outlineView selectedItems]) {
            if( [resource isKindOfClass: [Resource class]] ) {
                [self openResourceUsingEditor:resource];
            } else {
                [outlineView expandItem:resource];
            }
		}
	}
}

- (IBAction)openResourcesInTemplate:(id)sender
{
	// opens the resource in its default template
	for (Resource *resource in [outlineView selectedItems]) {
        if( [resource isKindOfClass: [Resource class]] ) {
            [self openResource:resource usingTemplate:GetNSStringFromOSType([resource type])];
        }
	}
}

- (IBAction)openResourcesAsHex:(id)sender
{
	for (Resource *resource in [outlineView selectedItems]) {
        if( [resource isKindOfClass: [Resource class]] ) {
            [self openResourceAsHex:resource];
        }
	}
}


/* -----------------------------------------------------------------------------
	openResourceUsingEditor:
		Open an editor for the specified Resource instance. This looks up
		the editor to use in the plugin registry and then instantiates an
		editor object, handing it the resource. If there is no editor for this
		type registered, it falls back to the template editor, which in turn
		uses the hex editor as a fallback.
	
	REVISIONS:
		2003-07-31  UK  Changed to use plugin registry instead of file name.
		2012-07-07	NW	Changed to return the used plugin.
   -------------------------------------------------------------------------- */

/* Method name should be changed to:  -(void)openResource:(Resource *)resource usingEditor:(Class)overrideEditor <nil == default editor>   */

- (id <ResKnifePlugin>)openResourceUsingEditor:(Resource *)resource
{
	Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:GetNSStringFromOSType([resource type])];
	
	// open the resources, passing in the template to use
	if(editorClass)
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		// update: doug says window controllers automatically release themselves when their window is closed. All default plugs have a window controller as their principal class, but 3rd party ones might not
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
		id plug = [(id <ResKnifePlugin>)[editorClass alloc] initWithResource:resource];
        if (plug) {
            if ([plug isKindOfClass:[NSWindowController class]]) {
                [self addWindowController:plug];
                [plug setDocumentEdited:NO];
            }
			return plug;
        }
	}
	
	// if no editor exists, or the editor is broken, open using template
	return [self openResource:resource usingTemplate:GetNSStringFromOSType([resource type])];
}


/* -----------------------------------------------------------------------------
	openResource:usingTemplate:
		Open a template editor for the specified Resource instance. This looks
		up the template editor in the plugin registry and then instantiates an
		editor object, handing it the resource and the template resource to use.
		If there is no template editor registered, or there is no template for
		this resource type, it falls back to the hex editor.
	
	REVISIONS:
		2003-07-31  UK  Changed to use plugin registry instead of file name.
		2012-07-07	NW	Changed to return the used plugin.
   -------------------------------------------------------------------------- */

- (id <ResKnifePlugin>)openResource:(Resource *)resource usingTemplate:(NSString *)templateName
{
	// opens resource in template using TMPL resource with name templateName
    if (resource.type) {
        Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:@"Template Editor"];
        
        // TODO: this checks EVERY DOCUMENT for template resources (might not be desired)
        // TODO: it doesn't, however, check the application's resource map for a matching template!
        Resource *tmpl = [Resource resourceOfType:'TMPL' withName:GetNSStringFromOSType([resource type]) inDocument:nil];
        
        // open the resources, passing in the template to use
        if(tmpl && editorClass)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
            id plug = [(id <ResKnifeTemplatePlugin>)[editorClass alloc] initWithResource:resource template:tmpl];
            if (plug) {
                [self addWindowController:plug];
                [plug setDocumentEdited:NO];
                return plug;
            }
        }
    }
	
	// if no template exists, or template editor is broken, open as hex
	return [self openResourceAsHex:resource];
}

/*!
@method			openResourceAsHex:
@author			Nicholas Shanks
@created		2001
@updated		2003-07-31 UK:	Changed to use plugin registry instead of file name.
				2012-07-07 NW:	Changed to return the used plugin.
@description	Open a hex editor for the specified Resource instance. This looks up the hexadecimal editor in the plugin registry and then instantiates an editor object, handing it the resource.
@param			resource	Resource to edit
*/

- (id <ResKnifePlugin>)openResourceAsHex:(Resource *)resource
{
	Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType: @"Hexadecimal Editor"];
	// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
	// update: doug says window controllers automatically release themselves when their window is closed.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	id plug = [(id <ResKnifePlugin>)[editorClass alloc] initWithResource:resource];
    [self addWindowController:plug];
    [plug setDocumentEdited:NO];
	return plug;
}


- (void)saveSoundAsMovie:(NSData *)sndData
{

}

/*!
@method			playSound:
@abstract		Plays the selected carbon 'snd ' resource.
@author			Nicholas Shanks
@created		2001
@updated		2003-10-22 NGS: Moved playing into seperate thread to avoid locking up main thread.
@pending		should really be moved to a 'snd ' editor, but first we'd need to extend the plugin protocol to call the class so it can add such menu items. Of course, we could just make the 'snd ' editor have a button in its window that plays the sound.
@description	This method is called from a menu item which is validated against there being only one selected resource (of type 'snd '), so shouldn't have to deal with playing multiple sounds, though this may of course change in future.
@param	sender	ignored
*/
- (IBAction)playSound:(id)sender
{
	// bug: can only cope with one selected item
	NSData *data = [(Resource *)[outlineView itemAtRow:[outlineView selectedRow]] data];
	if(data && [data length] != 0) {
		xpc_connection_t connection = xpc_connection_create("org.derailer.ResKnife.System7SoundPlayer", NULL);
		xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
		xpc_dictionary_set_data(dict, "soundData", [data bytes], [data length]);
		xpc_connection_set_event_handler(connection, ^(xpc_object_t object) {
			if (xpc_get_type(object) == XPC_TYPE_ERROR) {
				if (object == XPC_ERROR_CONNECTION_INVALID)
					NSLog(@"invalid connection");
			}
		});
		xpc_connection_resume(connection);
		xpc_connection_send_message(connection, dict);
	}
	else NSBeep();
}

- (void)resourceNameWillChange:(NSNotification *)notification
{
	// this saves the current resource's name so we can undo the change
	Resource *resource = (Resource *) [notification object];
    if ([resource document] == self) {
        [[self undoManager] registerUndoWithTarget:resource selector:@selector(setName:) object:[[resource name] copy]];
        [[self undoManager] setActionName:NSLocalizedString(@"Name Change", nil)];
    }
}

- (void)resourceIDWillChange:(NSNotification *)notification
{
	// this saves the current resource's ID number so we can undo the change
	Resource *resource = (Resource *) [notification object];
    if ([resource document] == self) {
        [[[self undoManager] prepareWithInvocationTarget:resource] setResID:[resource resID]];
        if([[resource name] length] == 0)
            [[self undoManager] setActionName:NSLocalizedString(@"ID Change", nil)];
        else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"ID Change for '%@'", nil), [resource name]]];
    }
}

- (void)resourceTypeWillChange:(NSNotification *)notification
{
	// this saves the current resource's type so we can undo the change
	Resource *resource = (Resource *) [notification object];
    if ([resource document] == self) {
        [(Resource*)[[self undoManager] prepareWithInvocationTarget:resource] setType:[resource type]];
        if([[resource name] length] == 0)
            [[self undoManager] setActionName:NSLocalizedString(@"Type Change", nil)];
        else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Type Change for '%@'", nil), [resource name]]];
    }
}

- (void)resourceAttributesWillChange:(NSNotification *)notification
{
	// this saves the current state of the resource's attributes so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setAttributes:) object:[@([resource attributes]) copy]];
	if([[resource name] length] == 0)
		[[self undoManager] setActionName:NSLocalizedString(@"Attributes Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Attributes Change for '%@'", nil), [resource name]]];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	[self updateChangeCount:NSChangeDone];
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
	NSArray *selectedItems = [dataSource allResourcesForItems:[outlineView selectedItems]];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	[pb declareTypes:@[RKResourcePboardType] owner:self];
	[pb setData:[NSKeyedArchiver archivedDataWithRootObject:selectedItems] forType:RKResourcePboardType];
}

- (IBAction)paste:(id)sender
{
	#pragma unused(sender)
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	if([pb availableTypeFromArray:@[RKResourcePboardType]])
		[self pasteResources:[NSKeyedUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
}

- (void)pasteResources:(NSArray *)pastedResources
{
	Resource *resource;
	NSEnumerator *enumerator = [pastedResources objectEnumerator];
	while(resource = (Resource *) [enumerator nextObject])
	{
		// check resource type/ID is available
		if([dataSource resourceOfType:[resource type] andID:[resource resID]] == nil)
		{
			// resource slot is available, paste this one in
			[dataSource addResource:resource];
		}
		else
		{
			// resource slot is ocupied, ask user what to do
			NSArray *remainingResources = [enumerator allObjects];
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Paste Error";
			alert.informativeText = [NSString stringWithFormat:@"There already exists a resource of type %@ with ID %hd. Do you wish to assign the pasted resource a unique ID, overwrite the existing resource, or skip pasting of this resource?", GetNSStringFromOSType([resource type]), [resource resID]];
			[alert addButtonWithTitle:@"Unique ID"];
			[alert addButtonWithTitle:@"Overwrite"];
			[alert addButtonWithTitle:@"Skip"];
			[alert beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse returnCode) {
				if(returnCode == NSAlertFirstButtonReturn)	// unique ID
				{
					Resource *newResource = [Resource resourceOfType:[resource type] andID:[self.dataSource uniqueIDForType:[resource type]] withName:[resource name] andAttributes:[resource attributes] data:[resource data]];
					[self.dataSource addResource:newResource];
				}
				else if(returnCode == NSAlertSecondButtonReturn)				// overwrite
				{
					[self.dataSource removeResource:[self.dataSource resourceOfType:[resource type] andID:[resource resID]]];
					[self.dataSource addResource:resource];
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:kDeleteResourceWarning])
	{
		NSBeginCriticalAlertSheet(@"Delete Resource", @"Delete", @"Cancel", nil, [self mainWindow], self, @selector(deleteResourcesSheetDidEnd:returnCode:contextInfo:), NULL, nil, @"Are you sure you want to delete the selected resources?");
	}
	else [self deleteSelectedResources];
}

- (void)deleteResourcesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
#pragma unused(contextInfo)
	if(returnCode == NSOKButton)
		[self deleteSelectedResources];
}

- (void)deleteSelectedResources
{
	Resource *resource;
	NSEnumerator *enumerator;
    NSArray *selected = [dataSource allResourcesForItems:[outlineView selectedItems]];
	
	// enumerate through array and delete resources
	[[self undoManager] beginUndoGrouping];
	enumerator = [selected reverseObjectEnumerator];		// reverse so an undo will replace items in original order
	while(resource = [enumerator nextObject])
	{
		[dataSource removeResource:resource];
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

- (IBAction)creatorChanged:(id)sender
{
	OSType newCreator = GetOSTypeFromNSString([sender stringValue]);
	[self setCreator:newCreator];
}

- (IBAction)typeChanged:(id)sender
{
	OSType newType = GetOSTypeFromNSString([sender stringValue]);
	[self setType:newType];
}

- (void)setCreator:(OSType)newCreator
{
	if (newCreator != _creator) {
		NSString *oldCreatorStr = GetNSStringFromOSType(newCreator);
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:@{@"NSDocument": self, @"creator": oldCreatorStr}];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setCreator:) object:GetNSStringFromOSType(_creator)];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Creator Code", nil)];
		_creator = newCreator;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:@{@"NSDocument": self, @"creator": oldCreatorStr}];
	}
}

- (void)setType:(OSType)newType
{
	if (newType != _type) {
		NSString *oldTypeStr = GetNSStringFromOSType(newType);
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:@{@"NSDocument": self, @"type": oldTypeStr}];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setType:) object:GetNSStringFromOSType(_type)];
		[[self undoManager] setActionName:NSLocalizedString(@"Change File Type", nil)];
		_type = newType;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:@{@"NSDocument": self, @"type": oldTypeStr}];
	}
}

- (IBAction)changeView:(id)sender
{
	
}

@end
