#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "Resource.h"
#import "ApplicationDelegate.h"
#import "OpenPanelDelegate.h"
#import "OutlineViewDelegate.h"
#import "InfoWindowController.h"
#import "PrefsWindowController.h"
#import "CreateResourceSheetController.h"
#import "../Categories/NGSCategories.h"
#import "../Categories/NSString-FSSpec.h"
#import "../Categories/NSOutlineView-SelectedItems.h"
#import <Carbon/Carbon.h>

#import "../Plug-Ins/ResKnifePluginProtocol.h"
#import "RKEditorRegistry.h"


NSString *DocumentInfoWillChangeNotification		= @"DocumentInfoWillChangeNotification";
NSString *DocumentInfoDidChangeNotification			= @"DocumentInfoDidChangeNotification";
extern NSString *RKResourcePboardType;

@implementation ResourceDocument

- (id)init
{
	self = [super init];
	if(!self) return nil;
	toolbarItems = [[NSMutableDictionary alloc] init];
	resources = [[NSMutableArray alloc] init];
	fork = nil;
	creator = [[@"ResK" dataUsingEncoding:NSMacOSRomanStringEncoding] retain];	// should I be calling -setCreator & -setType here instead?
	type = [[@"rsrc" dataUsingEncoding:NSMacOSRomanStringEncoding] retain];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if(fork) DisposePtr((Ptr) fork);
	[resources release];
	[toolbarItems release];
	[type release];
	[creator release];
	[sheetController release];
	[super dealloc];
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

-(BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)fileKind
{
	BOOL			succeeded = NO;
	OSStatus		error = noErr;
	FSRef			*fileRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	ResFileRefNum	fileRefNum = 0;
	OpenPanelDelegate *openPanelDelegate = [(ApplicationDelegate *)[NSApp delegate] openPanelDelegate];
	
	// bug: need to handle error better here
	error = FSPathMakeRef((const UInt8 *)[fileName fileSystemRepresentation], fileRef, nil);
	if(error) return NO;
	
	// find out which fork to parse
	if(NSAppKitVersionNumber < 700.0 || ![openPanelDelegate readOpenPanelForFork])
	{
		// display second dialog to ask user to select a fork, pre-10.3 or if open command did not come via the open dialog
		
		// bug:	unimplemented - always tells app to try resource fork first
		fork = (HFSUniStr255 *) NewPtrClear(sizeof(HFSUniStr255));
		error = FSGetResourceForkName(fork);
		if(error) return NO;
	}
	else
	{
		// get selected fork from open panel, 10.3+
		int row = [[openPanelDelegate forkTableView] selectedRow];
		NSString *selectedFork = [(NSDictionary *)[[openPanelDelegate forks] objectAtIndex:row] objectForKey:@"forkname"];
		fork = (HFSUniStr255 *) NewPtrClear(sizeof(HFSUniStr255));
		fork->length = ([selectedFork length] < 255) ? (UInt16)[selectedFork length] : 255;
		if(fork->length > 0)
			[selectedFork getCharacters:fork->unicode range:NSMakeRange(0,fork->length)];
		else fork->unicode[0] = 0;
		
		// clear so next document doesn't get confused
		[openPanelDelegate setReadOpenPanelForFork:NO];
	}
	
	NSArray *forks = [(ApplicationDelegate *)[NSApp delegate] forksForFile:fileRef];
	
	// attempt to open fork user selected as a resource map
	SetResLoad(false);		// don't load "preload" resources
	error = FSOpenResourceFile(fileRef, fork->length, (UniChar *) &fork->unicode, fsRdPerm, &fileRefNum);
	if(error || !fileRefNum)
	{
		// if opening the user-selected fork fails, try to open resource fork instead
		error = FSGetResourceForkName(fork);
		if(error) return NO;
/*		HFSUniStr255 *rfork;
		error = FSGetResourceForkName(rfork);
		if(error) return NO;
		
		bool checkFork = true;
		if(FSCreateStringFromHFSUniStr)	// 10.4 only
		{
			if(CFStringCompare(FSCreateStringFromHFSUniStr(NULL, fork), FSCreateStringFromHFSUniStr(NULL, rfork), 0) == NSOrderedSame)
				checkFork = false;	// skip checking resource fork if it's the one the user chose
			else fork = rfork;
		}
		if(checkFork)
*/			error = FSOpenResourceFile(fileRef, fork->length, (UniChar *) &fork->unicode, fsRdPerm, &fileRefNum);
		if(error || !fileRefNum)
		{
			// if opening the resource fork fails, try to open data fork instead
			error = FSGetDataForkName(fork);
			if(error) return NO;
			error = FSOpenResourceFile(fileRef, fork->length, (UniChar *) &fork->unicode, fsRdPerm, &fileRefNum);
			if(error || !fileRefNum)
			{
				// bug: should check fork the user selected is empty before trying data fork
				NSNumber *fAlloc = [[forks firstObjectReturningValue:[NSString stringWithCharacters:fork->unicode length:fork->length] forKey:@"forkname"] objectForKey:@"forkallocation"];
				if([fAlloc unsignedLongLongValue] > 0)
				{
					// data fork is not empty, check resource fork
					error = FSGetResourceForkName(fork);
					if(error) return NO;
					fAlloc = [[forks firstObjectReturningValue:[NSString stringWithCharacters:fork->unicode length:fork->length] forKey:@"forkname"] objectForKey:@"forkallocation"];
					if([fAlloc unsignedLongLongValue] > 0)
					{
						// resource fork is not empty either, give up (ask user for a fork?)
						NSLog(@"Could not find existing map nor create a new map in either the data or resource forks! Aborting.");
						return NO;
					}
				}
				
				// note that map needs initalising on first save
				_createFork = YES;
			}
		}
	}
	SetResLoad(true);			// restore resource loading as soon as is possible
	
	if(!_createFork)
	{
		// disable undos during resource creation and setting of the creator and type
		[[self undoManager] disableUndoRegistration];
		
		// then read resources from the selected fork
		succeeded = [self readResourceMap:fileRefNum];
		
		// get creator and type
		FSCatalogInfo info;
		error = FSGetCatalogInfo(fileRef, kFSCatInfoFinderInfo, &info, NULL, NULL, NULL);
		if(!error)
		{
			[self setType:[NSData dataWithBytes:&((FileInfo *)info.finderInfo)->fileType length:4]];
			[self setCreator:[NSData dataWithBytes:&((FileInfo *)info.finderInfo)->fileCreator length:4]];
		}
		
		// restore undos
		[[self undoManager] enableUndoRegistration];
	}
	else succeeded = YES;
	
	// now read all other forks as streams
	NSString *forkName;
	NSEnumerator *forkEnumerator = [forks objectEnumerator];
	NSString *selectedFork = [NSString stringWithCharacters:fork->unicode length:fork->length];
	while((forkName = [[forkEnumerator nextObject] objectForKey:@"forkname"]))
	{
		// check current fork is not the fork we're going to parse
		if(![forkName isEqualToString:selectedFork])
			[self readFork:forkName asStreamFromFile:fileRef];
	}
	
	// tidy up loose ends
	if(fileRefNum) FSCloseFork(fileRefNum);
	//DisposePtr((Ptr) fileRef);
	return succeeded;
}

/*!
@method			readFork:asStreamFromFile:
@author			Nicholas Shanks
@updated		2003-11-08 NGS:	Now handles opening user-selected forks.
@description	Note: there is a 2 GB limit to the size of forks that can be read in due to <tt>FSReaadFork()</tt> taking a 32-bit buffer length value.
*/

- (BOOL)readFork:(NSString *)forkName asStreamFromFile:(FSRef *)fileRef
{
	if(!fileRef) return NO;
	
	/* NTFS Note: When running SFM (Services for Macintosh) a Windows NT-based system (including 2000 & XP) serving NTFS-formatted drives stores Mac resource forks in a stream named "AFP_Resource". The finder info/attributes are stored in a stream called "AFP_AfpInfo". The default data fork stream is called "$DATA" and any of these can be accessed thus: "c:\filename.txt:forkname". Finder comments are stored in a stream called "Comments".
	As a result, ResKnife prohibits creation of forks with the following names:	"" (empty string, Mac data fork name),
																				"$DATA" (NTFS data fork name),
																				"AFP_Resource", "AFP_AfpInfo" and "Comments".
	It is perfectly legal in ResKnife to read in forks of these names when accessing a shared NTFS drive via SMB. The server does not need to be running SFM since the file requests will appear to be coming from a PC. If the files are accessed via AFP on a server running SFM, SFM will automatically convert the files (and truncate the name to 31 chars). */
	
	
	// translate NSString into HFSUniStr255 -- in 10.4 this can be done with FSGetHFSUniStrFromString
	HFSUniStr255 uniForkName = { 0 };
	uniForkName.length = ([forkName length] < 255)? (UInt16)[forkName length]:255;
	if(uniForkName.length > 0)
		[forkName getCharacters:uniForkName.unicode range:NSMakeRange(0, uniForkName.length)];
	else uniForkName.unicode[0] = 0;
	
	// get fork length and create empty buffer, bug: only sizeof(size_t) bytes long
	ByteCount forkLength = (ByteCount) [[[[(ApplicationDelegate *)[NSApp delegate] forksForFile:fileRef] firstObjectReturningValue:forkName forKey:@"forkname"] objectForKey:@"forksize"] unsignedLongValue];
	void *buffer = malloc(forkLength);
	if(!buffer) return NO;
	
	// read fork contents into buffer, bug: assumes no errors
	FSIORefNum forkRefNum;
	FSOpenFork(fileRef, uniForkName.length, uniForkName.unicode, fsRdPerm, &forkRefNum);
	FSReadFork(forkRefNum, fsFromStart, 0, forkLength, buffer, &forkLength);
	FSCloseFork(forkRefNum);
	
	// create data
	NSData *data = [NSData dataWithBytesNoCopy:buffer length:forkLength freeWhenDone:YES];
	if(!data) return NO;
	
	// create resource
	Resource *resource = [Resource resourceOfType:@"" andID:0 withName:forkName andAttributes:0 data:data];
	if(!resource) return NO;
	
	// customise fork name for default data & resource forks - bug: this should really be in resource data source!!
	HFSUniStr255 resourceForkName;
	OSErr error = FSGetResourceForkName(&resourceForkName);
	if(!error && [[resource name] isEqualToString:@""])			// bug: should use FSGetDataForkName()
		[resource _setName:NSLocalizedString(@"Data Fork", nil)];
	else if(!error && [[resource name] isEqualToString:[NSString stringWithCharacters:resourceForkName.unicode length:resourceForkName.length]])
		[resource _setName:NSLocalizedString(@"Resource Fork", nil)];
	
	[resource setRepresentedFork:forkName];
	[resources addObject:resource];
	return YES;
}

-(BOOL)readResourceMap:(ResFileRefNum)fileRefNum
{
	OSStatus error = noErr;
	ResFileRefNum oldResFile = CurResFile();
	UseResFile(fileRefNum);
	
	for(unsigned short i = 1; i <= Count1Types(); i++)
	{
		ResType resTypeCode;
		Get1IndType(&resTypeCode, i);
		unsigned short n = Count1Resources(resTypeCode);
		for(unsigned short j = 1; j <= n; j++)
		{
			Handle resourceHandle = Get1IndResource(resTypeCode, j);
			error = ResError();
			if(error != noErr)
			{
				NSLog(@"Error %d reading resource map...", error);
				UseResFile(oldResFile);
				return NO;
			}
			
			Str255 nameStr;
			short resIDShort;
			GetResInfo(resourceHandle, &resIDShort, &resTypeCode, nameStr);
			long sizeLong = GetResourceSizeOnDisk(resourceHandle), badSize = 0;
			if (sizeLong < 0 || sizeLong > 16777215)	// the max size of resource manager file is ~12 MB; I am rounding up to three bytes
			{
				// this only happens when opening ResEdit using the x86 binary (not under Rosetta, for example)
				badSize = sizeLong;
				sizeLong = EndianS32_BtoL(sizeLong);
			}
			short attrsShort = GetResAttrs(resourceHandle);
			HLockHi(resourceHandle);
#if __LITTLE_ENDIAN__
			CoreEndianFlipData(kCoreEndianResourceManagerDomain, resTypeCode, resIDShort, *resourceHandle, sizeLong, true);
#endif
			
			// cool: "The advantage of obtaining a methodÕs implementation and calling it as a function is that you can invoke the implementation multiple times within a loop, or similar C construct, without the overhead of Objective-C messaging."
			
			// create the resource & add it to the array
			ResType		logicalType = EndianS32_NtoB(resTypeCode);	// swapped type for use as string (types are treated as numbers by the resource manager and swapped on Intel).
			NSString	*name		= [[NSString alloc] initWithBytes:&nameStr[1] length:nameStr[0] encoding:NSMacOSRomanStringEncoding];
			NSString	*resType	= [[NSString alloc] initWithBytes:(char *) &logicalType length:4 encoding:NSMacOSRomanStringEncoding];
			NSNumber	*resID		= [NSNumber numberWithShort:resIDShort];
			NSNumber	*attributes	= [NSNumber numberWithShort:attrsShort];
			NSData		*data		= [NSData dataWithBytes:*resourceHandle length:sizeLong];
			Resource	*resource	= [Resource resourceOfType:resType andID:resID withName:name andAttributes:attributes data:data];
			[resource setDocumentName:[self displayName]];
			[resources addObject:resource];		// array retains resource
			if (badSize != 0)
				NSLog(@"GetResourceSizeOnDisk() reported incorrect size for %@ resource %@ in %@: %li should be %li", resType, resID, [self displayName], badSize, sizeLong);
			[name release];
			[resType release];
			
			HUnlock(resourceHandle);
			ReleaseResource(resourceHandle);
		}
	}
	
	// save resource map and clean up
	UseResFile(oldResFile);
	return YES;
}

/*!
@pending	Uli has changed this routine - see what I had and unify the two
@pending	Doesn't write correct type/creator info - always ResKnife's!
*/

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type
{
	OSStatus error = noErr;
	ResFileRefNum fileRefNum = 0;
	FSRef *parentRef	= (FSRef *) NewPtrClear(sizeof(FSRef));
	FSRef *fileRef		= (FSRef *) NewPtrClear(sizeof(FSRef));
	
	// create and open file for writing
	// bug: doesn't set the cat info to the same as the old file
	unichar *uniname = (unichar *) NewPtrClear(sizeof(unichar) *256);
	[[fileName lastPathComponent] getCharacters:uniname];
	error = FSPathMakeRef((const UInt8 *)[[fileName stringByDeletingLastPathComponent] UTF8String], parentRef, nil);
	
	if (error != noErr)
		NSLog(@"FSPathMakeRef got error %d", error);
	
	if(fork)
		error = FSCreateResourceFile(parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, NULL, fork->length, (UniChar *) &fork->unicode, fileRef, NULL);
	else error = FSCreateResourceFile(parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, NULL, 0, NULL, fileRef, NULL);
	
	// write any data streams to file
	BOOL succeeded = [self writeForkStreamsToFile:fileName];
//	FSRef *fileRef		= [fileName createFSRef];
	
/*	error = FSPathMakeRef((const UInt8 *)[fileName UTF8String], fileRef, nil);
	if(_createFork)
	{
		error = FSCreateResourceFork(fileRef, fork->length, (UniChar *) &fork->unicode, 0);
		_createFork = NO;
	}
*/	
	if(!error)
	{
		// set creator & type
		// bug: due to a bug in AppKit, the temporary file that we are writing to (in /var/tmp, managed by NSDocument) does not get it's creator code copied over to the new document (it sets the new document's to nil). this timer sets the creator code after we have returned to the main loop and the buggy Apple code has been bypassed.
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(setTypeCreatorAfterSave:) userInfo:nil repeats:NO];
		
		// open fork as resource map
		if(fork)
			error = FSOpenResourceFile(fileRef, fork->length, (UniChar *) &fork->unicode, fsWrPerm, &fileRefNum);
		else error = FSOpenResourceFile(fileRef, 0, NULL, fsWrPerm, &fileRefNum);
	}
//	else NSLog(@"error creating resource fork. (error=%d, spec=%d, ref=%d, parent=%d)", error, fileSpec, fileRef, parentRef);
	else NSLog(@"error creating resource fork. (error=%d, ref=%p)", error, fileRef);
	
	// write resource array to file
	if(fileRefNum && !error)
		succeeded = [self writeResourceMap:fileRefNum];
	
	// tidy up loose ends
	if(fileRefNum) FSCloseFork(fileRefNum);
	DisposePtr((Ptr) fileRef);
	
	// update info window
	[[InfoWindowController sharedInfoWindowController] updateInfoWindow];
	
	return succeeded;
}

- (BOOL)writeForkStreamsToFile:(NSString *)fileName
{
	// try and get an FSRef
	OSStatus error;
	FSRef *fileRef = [fileName createFSRef], *parentRef = nil;
	if(!fileRef)
	{
		parentRef = (FSRef *) NewPtrClear(sizeof(FSRef));
		fileRef   = (FSRef *) NewPtrClear(sizeof(FSRef));
		unichar *uniname = (unichar *) NewPtrClear(sizeof(unichar) *256);
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSPathMakeRef((const UInt8 *)[[fileName stringByDeletingLastPathComponent] UTF8String], parentRef, nil);
		if(error) return NO;
		error = FSCreateFileUnicode(parentRef, 0, NULL, kFSCatInfoNone, NULL, fileRef, NULL);
		if(error || !fileRef) return NO;
	}
	
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		// if the resource object represents an actual resource, skip it
		if([resource representedFork] == nil) continue;
		unichar *uniname = (unichar *) NewPtrClear(sizeof(unichar) *256);
		[[resource representedFork] getCharacters:uniname];
		FSIORefNum forkRefNum = 0;
		error = FSOpenFork(fileRef, [[resource representedFork] length], (UniChar *) uniname, fsWrPerm, &forkRefNum);
		
		if (error != noErr)
			NSLog(@"FSOpenFork got error %d", error);
		
		if(!error && forkRefNum)
			error = FSWriteFork(forkRefNum, fsFromStart, 0, [[resource data] length], [[resource data] bytes], NULL);
		
		if (error != noErr)
			NSLog(@"FSWriteFork got error %d", error);
		
		if(forkRefNum) FSCloseFork(forkRefNum);
	}
	DisposePtr((Ptr) fileRef);
	return YES;
}

/*!
@method		writeResourceMap:
@abstract   Writes all resources (except the ones representing other forks of the file) to the specified resource file.
*/

- (BOOL)writeResourceMap:(ResFileRefNum)fileRefNum
{
	// make the resource file current
	OSStatus error = noErr;
	ResFileRefNum oldResFile = CurResFile();
	UseResFile(fileRefNum);
	
	// loop over all our resources
	Resource *resource;
	NSEnumerator *enumerator = [resources objectEnumerator];
	while(resource = [enumerator nextObject])
	{
		Str255	nameStr;
		ResType	resTypeCode;
		char	resTypeStr[5];		// includes null char for getCString:
		short	resIDShort;
		short	attrsShort;
		long	sizeLong;
		Handle	resourceHandle;

		// if the resource represents another fork in the file, skip it
		if([resource representedFork] != nil) continue;
		
		sizeLong = [[resource data] length];
		resIDShort	= [[resource resID] shortValue];
		attrsShort	= [[resource attributes] shortValue];
		resourceHandle = NewHandleClear(sizeLong);
		
		// convert unicode name to pascal string
		nameStr[0] = (unsigned char)[[resource name] lengthOfBytesUsingEncoding:NSMacOSRomanStringEncoding];
		memmove(&nameStr[1], [[resource name] cStringUsingEncoding:NSMacOSRomanStringEncoding], nameStr[0]);
		
		// convert type string to ResType
		[[resource type] getCString:resTypeStr maxLength:4 encoding:NSMacOSRomanStringEncoding];
		resTypeCode = CFSwapInt32HostToBig(*(ResType *)resTypeStr);
		
		// convert NSData to resource handle
		HLockHi(resourceHandle);
		[[resource data] getBytes:*resourceHandle];
#if __LITTLE_ENDIAN__
		CoreEndianFlipData(kCoreEndianResourceManagerDomain, resTypeCode, resIDShort, *resourceHandle, sizeLong, false);
#endif
		HUnlock(resourceHandle);
		
		// now that everything's converted, tell the resource manager we want to create this resource
		AddResource(resourceHandle, resTypeCode, resIDShort, nameStr);
		if(ResError() == addResFailed)
		{
			NSLog(@"*Saving failed*; could not add resource ID %@ of type %@ to file.", [resource resID], [resource type]);
			DisposeHandle(resourceHandle);
			error = addResFailed;
		}
		else
		{
//			NSLog(@"Added resource ID %@ of type %@ to file.", [resource resID], [resource type]);
			SetResAttrs(resourceHandle, attrsShort);
			ChangedResource(resourceHandle);
			// the resourceHandle memory is disposed of when calling CloseResFile() for the file to which the resource has been added
		}
	}
	
	// update the file on disk
	UpdateResFile(fileRefNum);
	
	// restore original resource file
	UseResFile(oldResFile);
	return error? NO:YES;
}

- (void)setTypeCreatorAfterSave:(id)userInfo
{
	FSRef *fileRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	OSStatus error = FSPathMakeRef((const UInt8 *)[[[self fileURL] path] UTF8String], fileRef, nil);
	if(!error)
	{
		FSCatalogInfo info;
		error = FSGetCatalogInfo(fileRef, kFSCatInfoFinderInfo, &info, NULL, NULL, NULL);
		if(!error)
		{
			FInfo *finderInfo = (FInfo *)(info.finderInfo);
			[[self type] getBytes:&finderInfo->fdType length:4];
			[[self creator] getBytes:&finderInfo->fdCreator length:4];
			//				NSLog(@"setting finder info to type: %X; creator: %X", finderInfo.fdType, finderInfo.fdCreator);
			FSSetCatalogInfo(fileRef, kFSCatInfoFinderInfo, &info);
			//				NSLog(@"finder info got set to type: %X; creator: %X", finderInfo.fdType, finderInfo.fdCreator);
		}
		else NSLog(@"error getting Finder info. (error=%d, ref=%p)", error, fileRef);
	}
	else NSLog(@"error making fsref from file path. (error=%d, ref=%p, path=%@)", error, fileRef, [[self fileURL] path]);
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
	Class		editorClass = [[RKEditorRegistry defaultRegistry] editorForType:[resource type]];
	NSData		*exportData = [resource data];
	NSString	*extension = [[[resource type] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// basic overrides for file name extensions (assume no plug-ins installed)
	NSString *newExtension;
	NSDictionary *adjustments = [NSDictionary dictionaryWithObjectsAndKeys: @"ttf", @"sfnt", nil];
	if((newExtension = [adjustments objectForKey:extension]))
		extension = newExtension;
	
	// ask for data
	if([editorClass respondsToSelector:@selector(dataForFileExport:)])
		exportData = [editorClass dataForFileExport:resource];
	
	// ask for file extension
	if([editorClass respondsToSelector:@selector(filenameExtensionForFileExport:)])
		extension = [editorClass filenameExtensionForFileExport:resource];
	
	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *filename = [resource name] ? [resource name] : NSLocalizedString(@"Untitled Resource",nil);
	filename = [filename stringByAppendingPathExtension:extension];
	[panel setNameFieldStringValue:filename];
	//[panel beginSheetForDirectory:nil file:filename modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:) contextInfo:[exportData retain]];
	[panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
		[self exportPanelDidEnd:panel returnCode:result contextInfo:exportData];
	}];
}

- (void)exportPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSData *data = (NSData *) contextInfo;
	[data autorelease];
	
	if(returnCode == NSOKButton)
		[data writeToURL:[sheet URL] atomically:YES];
}

- (void)folderChoosePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSOKButton)
	{
		unsigned int i = 1;
		Resource *resource;
		NSString *filename, *extension;
		NSDictionary *adjustments = [NSDictionary dictionaryWithObjectsAndKeys: @"ttf", @"sfnt", @"png", @"PNGf", nil];
		NSEnumerator *enumerator = [[outlineView selectedItems] objectEnumerator];
		while(resource = [enumerator nextObject])
		{
			Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:[resource type]];
			NSData *exportData = [resource data];
			extension = [[[resource type] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			// basic overrides for file name extensions (assume no plug-ins installed)
			if([adjustments objectForKey:[resource type]])
				extension = [adjustments objectForKey:[resource type]];
			
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
	[self setupToolbar:controller];
	
	{	// set up first column in outline view to display images as well as text
		ResourceNameCell *resourceNameCell = [[[ResourceNameCell alloc] init] autorelease];
		[resourceNameCell setEditable:YES];
		[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:resourceNameCell];
//		NSLog(@"Changed data cell");
	}
	
	// set outline view's inter-cell spacing to zero to avoid getting gaps between blue bits
	[outlineView setIntercellSpacing:NSMakeSize(0,0)];
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(openResources:)];
	[outlineView setVerticalMotionCanBeginDrag:YES];
	[outlineView registerForDraggedTypes:[NSArray arrayWithObjects:RKResourcePboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
	
	// register for resource will change notifications (for undo management)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameWillChange:) name:ResourceNameWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceIDWillChange:) name:ResourceIDWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeWillChange:) name:ResourceTypeWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesWillChange:) name:ResourceAttributesWillChangeNotification object:nil];
	
//	[[controller window] setResizeIncrements:NSMakeSize(1,18)];
	[dataSource setResources:resources];
}

- (void)printShowingPrintPanel:(BOOL)flag
{
	NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:[mainWindow contentView]];
	[printOperation runOperationModalForWindow:mainWindow delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:nil];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo
{
	if(!success) NSLog(@"Printing Failed!");
}

- (BOOL)keepBackupFile
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PreserveBackups"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	int selectedRows = [outlineView numberOfSelectedRows];
	Resource *resource = (Resource *) [outlineView selectedItem];
	
	// file menu
	if([item action] == @selector(saveDocument:))			return [self isDocumentEdited];
	
	// edit menu
	else if([item action] == @selector(clear:))				return selectedRows > 0;
	else if([item action] == @selector(selectAll:))			return [outlineView numberOfRows] > 0;
	else if([item action] == @selector(deselectAll:))		return selectedRows > 0;
	
	// resource menu
	else if([item action] == @selector(openResources:))						return selectedRows > 0;
	else if([item action] == @selector(openResourcesInTemplate:))			return selectedRows > 0;
	else if([item action] == @selector(openResourcesWithOtherTemplate:))	return selectedRows > 0;
	else if([item action] == @selector(openResourcesAsHex:))				return selectedRows > 0;
	else if([item action] == @selector(exportResourceToImageFile:))
	{
		if(selectedRows < 1) return NO;
		Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:[resource type]];
		return [editorClass respondsToSelector:@selector(imageForImageFileExport:)];
	}
	else if([item action] == @selector(playSound:))				return selectedRows == 1 && [[resource type] isEqualToString:@"snd "];
	else if([item action] == @selector(revertResourceToSaved:))	return selectedRows == 1 && [resource isDirty];
	else return [super validateMenuItem:item];
}

#pragma mark -
#pragma mark Toolbar Management

static NSString *RKToolbarIdentifier		= @"com.nickshanks.resknife.toolbar";
static NSString *RKCreateItemIdentifier		= @"com.nickshanks.resknife.toolbar.create";
static NSString *RKDeleteItemIdentifier		= @"com.nickshanks.resknife.toolbar.delete";
static NSString *RKEditItemIdentifier		= @"com.nickshanks.resknife.toolbar.edit";
static NSString *RKEditHexItemIdentifier	= @"com.nickshanks.resknife.toolbar.edithex";
static NSString *RKSaveItemIdentifier		= @"com.nickshanks.resknife.toolbar.save";
static NSString *RKShowInfoItemIdentifier	= @"com.nickshanks.resknife.toolbar.showinfo";
static NSString *RKExportItemIdentifier		= @"com.nickshanks.resknife.toolbar.export";

- (void)setupToolbar:(NSWindowController *)windowController
{
	/* This routine should become invalid once toolbars are integrated into nib files */
	
	NSToolbarItem *item;
	[toolbarItems removeAllObjects];	// just in case this method is called more than once per document (which it shouldn't be!)
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKCreateItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Create", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Create", nil)];
	[item setToolTip:NSLocalizedString(@"Create New Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Create"]];
	[item setTarget:self];
	[item setAction:@selector(showCreateResourceSheet:)];
	[toolbarItems setObject:item forKey:RKCreateItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKDeleteItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Delete", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Delete", nil)];
	[item setToolTip:NSLocalizedString(@"Delete Selected Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Delete"]];
	[item setTarget:self];
	[item setAction:@selector(clear:)];
	[toolbarItems setObject:item forKey:RKDeleteItemIdentifier];
	
	NSImage *image;
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Edit", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource In Default Editor", nil)];
	if((image = [[NSWorkspace sharedWorkspace] iconForFileType:@"rtf"]))
	     [item setImage:image];
	else [item setImage:[NSImage imageNamed:@"Edit"]];
	[item setTarget:self];
	[item setAction:@selector(openResources:)];
	[toolbarItems setObject:item forKey:RKEditItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditHexItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource As Hexadecimal", nil)];
	if((image = [[NSWorkspace sharedWorkspace] iconForFileType:@"txt"]))
	     [item setImage:image];
	else [item setImage:[NSImage imageNamed:@"Edit Hex"]];
	[item setTarget:self];
	[item setAction:@selector(openResourcesAsHex:)];
	[toolbarItems setObject:item forKey:RKEditHexItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKSaveItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Save", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Save", nil)];
	[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Save To %@ Fork", nil), !fork? NSLocalizedString(@"Data", nil) : NSLocalizedString(@"Resource", nil)]];
	[item setImage:[NSImage imageNamed:@"Save"]];
	[item setTarget:self];
	[item setAction:@selector(saveDocument:)];
	[toolbarItems setObject:item forKey:RKSaveItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKShowInfoItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Show Info", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Show Info", nil)];
	[item setToolTip:NSLocalizedString(@"Show Resource Information Window", nil)];
	if((image = [NSImage imageNamed:NSImageNameInfo]))
	     [item setImage:image];
	else [item setImage:[NSImage imageNamed:@"Show Info"]];
	[item setTarget:[NSApp delegate]];
	[item setAction:@selector(showInfo:)];
	[toolbarItems setObject:item forKey:RKShowInfoItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKExportItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Export Data", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Export Resource Data", nil)];
	[item setToolTip:NSLocalizedString(@"Export the resource's data to a file", nil)];
	[item setImage:[NSImage imageNamed:@"Export"]];
	[item setTarget:self];
	[item setAction:@selector(exportResources:)];
	[toolbarItems setObject:item forKey:RKExportItemIdentifier];
	
	if([windowController window] == mainWindow)
	{
		NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:RKToolbarIdentifier] autorelease];
		
		// set toolbar properties
		[toolbar setVisible:YES];
		[toolbar setAutosavesConfiguration:YES];
		[toolbar setAllowsUserCustomization:YES];
		[toolbar setDisplayMode:NSToolbarDisplayModeDefault];
		
		// attach toolbar to window
		[toolbar setDelegate:self];
		[mainWindow setToolbar:toolbar];
	}
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [toolbarItems objectForKey:itemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKShowInfoItemIdentifier, RKDeleteItemIdentifier, NSToolbarSeparatorItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, NSToolbarSeparatorItemIdentifier, RKSaveItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKDeleteItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, RKSaveItemIdentifier, RKExportItemIdentifier, RKShowInfoItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	BOOL valid = NO;
	int selectedRows = [outlineView numberOfSelectedRows];
	NSString *identifier = [item itemIdentifier];
	
	if([identifier isEqualToString:RKCreateItemIdentifier])				valid = YES;
	else if([identifier isEqualToString:RKDeleteItemIdentifier])		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKEditItemIdentifier])			valid = selectedRows > 0;
	else if([identifier isEqualToString:RKEditHexItemIdentifier])		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKExportItemIdentifier])		valid = selectedRows > 0;
	else if([identifier isEqualToString:RKSaveItemIdentifier])			valid = [self isDocumentEdited];
	else if([identifier isEqualToString:NSToolbarPrintItemIdentifier])	valid = YES;
	
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
		NSArray *selected = [outlineView selectedItems];
		for (Resource *resource in selected) {
			id usedPlug = [self openResourceUsingEditor:resource];
			if ([usedPlug isKindOfClass:[NSWindowController class]])
				[self addWindowController:usedPlug];
		}
	}
}

- (IBAction)openResourcesInTemplate:(id)sender
{
	// opens the resource in its default template
	NSArray *selected = [outlineView selectedItems];
	for (Resource *resource in selected) {
		id usedPlug = [self openResource:resource usingTemplate:[resource type]];
		if ([usedPlug isKindOfClass:[NSWindowController class]])
			[self addWindowController:usedPlug];
	}
}

- (IBAction)openResourcesAsHex:(id)sender
{
	NSArray *selected = [outlineView selectedItems];
	for (Resource *resource in selected) {
		id usedPlug = [self openResourceAsHex:resource];
		if ([usedPlug isKindOfClass:[NSWindowController class]])
			[self addWindowController:usedPlug];
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

- (id <ResKnifePluginProtocol>)openResourceUsingEditor:(Resource *)resource
{
	Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:[resource type]];
	
	// open the resources, passing in the template to use
	if(editorClass)
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		// update: doug says window controllers automatically release themselves when their window is closed. All default plugs have a window controller as their principal class, but 3rd party ones might not
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
		id plug = [(id <ResKnifePluginProtocol>)[editorClass alloc] initWithResource:resource];
		if(plug) return plug;
	}
	
	// if no editor exists, or the editor is broken, open using template
	return [self openResource:resource usingTemplate:[resource type]];
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

- (id <ResKnifePluginProtocol>)openResource:(Resource *)resource usingTemplate:(NSString *)templateName
{
	// opens resource in template using TMPL resource with name templateName
	Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType:@"Template Editor"];
	
	// TODO: this checks EVERY DOCUMENT for template resources (might not be desired)
	// TODO: it doesn't, however, check the application's resource map for a matching template!
	Resource *tmpl = [Resource resourceOfType:@"TMPL" withName:[resource type] inDocument:nil];
	
	// open the resources, passing in the template to use
	if(tmpl && editorClass)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
		id plug = [(id <ResKnifeTemplatePluginProtocol>)[editorClass alloc] initWithResources:resource, tmpl, nil];
		if(plug) return plug;
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

- (id <ResKnifePluginProtocol>)openResourceAsHex:(Resource *)resource
{
	Class editorClass = [[RKEditorRegistry defaultRegistry] editorForType: @"Hexadecimal Editor"];
	// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
	// update: doug says window controllers automatically release themselves when their window is closed.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	id <ResKnifePluginProtocol> plugController = [(id <ResKnifePluginProtocol>)[editorClass alloc] initWithResource:resource];
	return plugController;
}


- (void)saveSoundAsMovie:(NSData *)sndData {

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
	if(data && [data length] != 0)
	{		
		[NSThread detachNewThreadSelector:@selector(playSoundThreadController:) toTarget:self withObject:data];
	}
	else NSBeep();
}

/*!
@method			playSoundThreadController:
@abstract		Plays a carbon 'snd ' resource.
@author			Nicholas Shanks
@created		2003-10-22
@pending		should really be moved to a 'snd ' editor, but first we'd need to extend the plugin protocol to call the class so it can add such menu items. Of course, we could just make the 'snd ' editor have a button in its window that plays the sound.
@description	This method was added to prevent having to use AsynchSoundHelper to play them asynchronously in the main thread and all the associated idle checking, which since we have no event loop, would have to have been called from a timer. I'm not sure if the autorelease pool is necessary, as no cocoa objects are created, but an NSData is passed in and messages sent to it, and NSBeep() might need one.
@param	data	An NSData object containing the snd resource data to be played.
*/

- (void)playSoundThreadController:(NSData *)data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(data && [data length] != 0)
	{
		// plays sound synchronously, thread exits when sound is done playing
#if !__LP64__
		SndListPtr sndPtr = (SndListPtr) [data bytes];
		SndPlay(nil, &sndPtr, false);
#endif
	}
	else NSBeep();
	[pool release];
}

/*!
@method		sound:didFinishPlaying:
@abstract	Called frequently when playing a sound via NSSound. Unused, here for reference and possible future use.
@author		Nicholas Shanks
@pending	should really be moved to a 'snd ' editor, but first we'd need to extend the plugin protocol to call the class so it can add such menu items. Of course, we could just make the 'snd ' editor have a button in its window that plays the sound.
@param		sound		The NSSound that is playing.
@param		finished	Flag to indicate if it has just finished and that we should clean up.
*/

- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finished
{
	// unused because I can't get NSSound to play snd resources, so I use Carbon's SndPlay(), above
	if(finished) [sound release];
	NSLog(@"sound released");
}

- (void)resourceNameWillChange:(NSNotification *)notification
{
	// this saves the current resource's name so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setName:) object:[[[resource name] copy] autorelease]];
	[[self undoManager] setActionName:NSLocalizedString(@"Name Change", nil)];
}

- (void)resourceIDWillChange:(NSNotification *)notification
{
	// this saves the current resource's ID number so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setResID:) object:[[[resource resID] copy] autorelease]];
	if([[resource name] length] == 0)
		[[self undoManager] setActionName:NSLocalizedString(@"ID Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"ID Change for '%@'", nil), [resource name]]];
}

- (void)resourceTypeWillChange:(NSNotification *)notification
{
	// this saves the current resource's type so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setType:) object:[[[resource type] copy] autorelease]];
	if([[resource name] length] == 0)
		[[self undoManager] setActionName:NSLocalizedString(@"Type Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Type Change for '%@'", nil), [resource name]]];
}

- (void)resourceAttributesWillChange:(NSNotification *)notification
{
	// this saves the current state of the resource's attributes so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setAttributes:) object:[[[resource attributes] copy] autorelease]];
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
	[self clear:sender];
}

- (IBAction)copy:(id)sender
{
	#pragma unused(sender)
	NSArray *selectedItems = [outlineView selectedItems];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	[pb declareTypes:[NSArray arrayWithObject:RKResourcePboardType] owner:self];
	[pb setData:[NSArchiver archivedDataWithRootObject:selectedItems] forType:RKResourcePboardType];
}

- (IBAction)paste:(id)sender
{
	#pragma unused(sender)
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	if([pb availableTypeFromArray:[NSArray arrayWithObject:RKResourcePboardType]])
		[self pasteResources:[NSUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
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
			NSMutableArray *remainingResources = [[NSMutableArray alloc] initWithCapacity:1];
			[remainingResources addObject:resource];
			[remainingResources addObjectsFromArray:[enumerator allObjects]];
			NSBeginAlertSheet(@"Paste Error", @"Unique ID", @"Skip", @"Overwrite", mainWindow, self, NULL, @selector(overwritePasteSheetDidDismiss:returnCode:contextInfo:), remainingResources, @"There already exists a resource of type %@ with ID %@. Do you wish to assign the pasted resource a unique ID, overwrite the existing resource, or skip pasting of this resource?", [resource type], [resource resID]);
		}
	}
}

- (void)overwritePasteSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSMutableArray *remainingResources = [NSMutableArray arrayWithArray:[(NSArray *)contextInfo autorelease]];
	Resource *resource = [remainingResources objectAtIndex:0];
	if(returnCode == NSAlertDefaultReturn)	// unique ID
	{
		Resource *newResource = [Resource resourceOfType:[resource type] andID:[dataSource uniqueIDForType:[resource type]] withName:[resource name] andAttributes:[resource attributes] data:[resource data]];
		[dataSource addResource:newResource];
	}
	else if(NSAlertOtherReturn)				// overwrite
	{
		[dataSource removeResource:[dataSource resourceOfType:[resource type] andID:[resource resID]]];
		[dataSource addResource:resource];
	}
//	else if(NSAlertAlternateReturn)			// skip
	
	// remove top resource and continue paste
	[remainingResources removeObjectAtIndex:0];
	[self pasteResources:remainingResources];
}

- (IBAction)clear:(id)sender
{
	#pragma unused(sender)
	if([prefs boolForKey:@"DeleteResourceWarning"])
	{
		NSBeginCriticalAlertSheet(@"Delete Resource", @"Delete", @"Cancel", nil, [self mainWindow], self, @selector(deleteResourcesSheetDidEnd:returnCode:contextInfo:), NULL, nil, @"Please confirm you wish to delete the selected resources.");
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
	NSArray *selectedItems = [outlineView selectedItems];
	
	// enumerate through array and delete resources
	[[self undoManager] beginUndoGrouping];
	enumerator = [selectedItems reverseObjectEnumerator];		// reverse so an undo will replace items in original order
	while(resource = [enumerator nextObject])
	{
		[dataSource removeResource:resource];
		if([[resource name] length] == 0)
			[[self undoManager] setActionName:NSLocalizedString(@"Delete Resource", nil)];
		else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Delete Resource '%@'", nil), [resource name]]];
	}
	[[self undoManager] endUndoGrouping];
	
	// generalise undo name if more than one was deleted
	if([outlineView numberOfSelectedRows] > 1)
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

- (NSArray *)resources
{
	return resources;
}

- (NSData *)creator
{
	return creator;
}

- (NSData *)type
{
	return type;
}

- (IBAction)creatorChanged:(id)sender
{
	unsigned long newCreator = 0x00;	// creator is nil by default
	NSData *creatorData = [[sender stringValue] dataUsingEncoding:NSMacOSRomanStringEncoding];
//	NSLog(@"creatorChanged: [sender stringValue] = '%@'; creatorData = '%@'", [sender stringValue], creatorData);
	if(creatorData && [creatorData length] > 0)
	{
		newCreator = '    ';			// pad with spaces if not nil
		[creatorData getBytes:&newCreator length:([creatorData length] < 4? [creatorData length]:4)];
	}
	
	newCreator = CFSwapInt32HostToBig(newCreator);
	
	[self setCreator:[NSData dataWithBytes:&newCreator length:4]];
//	NSLog(@"Creator changed to '%@'", [[[NSString alloc] initWithBytes:&newCreator length:4 encoding:NSMacOSRomanStringEncoding] autorelease]);
}

- (IBAction)typeChanged:(id)sender
{
	unsigned long newType = 0x00;
	NSData *typeData = [[sender stringValue] dataUsingEncoding:NSMacOSRomanStringEncoding];
//	NSLog(@"typeChanged: [sender stringValue] = '%@'; typeData = '%@'", [sender stringValue], typeData);
	if(typeData && [typeData length] > 0)
	{
		newType = '    ';
		[typeData getBytes:&newType length:([typeData length] < 4 ? [typeData length]:4)];
	}
	
	newType = CFSwapInt32HostToBig(newType);
	
	[self setType:[NSData dataWithBytes:&newType length:4]];
//	NSLog(@"Type changed to '%@'", [[[NSString alloc] initWithBytes:&newType length:4 encoding:NSMacOSRomanStringEncoding] autorelease]);
}

- (BOOL)setCreator:(NSData *)newCreator
{
	if(![newCreator isEqualToData:creator])
	{
		id old = creator;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newCreator, @"creator", nil]];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setCreator:) object:creator];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Creator Code", nil)];
		creator = [newCreator copy];
		[old release];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", creator, @"creator", nil]];
		return YES;
	}
	else return NO;
}

- (BOOL)setType:(NSData *)newType
{
	if(![newType isEqualToData:type])
	{
		id old = type;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newType, @"type", nil]];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setType:) object:type];
		[[self undoManager] setActionName:NSLocalizedString(@"Change File Type", nil)];
		type = [newType copy];
		[old release];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", type, @"type", nil]];
		return YES;
	}
	else return NO;
}

- (BOOL)setCreator:(NSData *)newCreator andType:(NSData *)newType
{
	BOOL creatorChanged, typeChanged;
	[[self undoManager] beginUndoGrouping];
	creatorChanged = [self setCreator:newCreator];
	typeChanged = [self setType:newType];
	[[self undoManager] endUndoGrouping];
	if(creatorChanged && typeChanged)
		[[self undoManager] setActionName:NSLocalizedString(@"Change Creator & Type", nil)];
	return (creatorChanged || typeChanged);
}

@end
