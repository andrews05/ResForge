#import "ResourceDocument.h"
#import "Resource.h"

@implementation ResourceDocument

- (id)init
{
	self = [super init];
	resources = [NSMutableArray array];
	otherFork = nil;
	return self;
}

- (void)dealloc
{
	if( otherFork )
		DisposePtr( (Ptr) otherFork );
	[resources release];
	[super dealloc];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"ResourceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that need to be executed once the windowController has loaded the document's window.
	[dataSource setResources:resources];
}

- (BOOL)keepBackupFile
{
	return NO;		// return whatever the user preference is for this! (NSDefaults)
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	NSString *file = [[[sender representedFilename] lastPathComponent] stringByDeletingPathExtension];
	if( [file isEqualToString:@""] ) file = @"this document";
	NSBeginAlertSheet( @"Save Document?", @"Save", @"Cancel", @"DonÕt Save", sender, self, @selector(didEndShouldCloseSheet:returnCode:contextInfo:), NULL, sender, @"Do you wish to save %@?", file );
	return NO;
}

- (void)didEndShouldCloseSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if( returnCode == NSAlertDefaultReturn )		// save then close
	{
		[self saveDocument:contextInfo];
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertOtherReturn )		// don't save, just close
	{
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertErrorReturn )
	{
		NSLog( @"didEndShouldCloseSheet received NSAlertErrorReturn return code" );
	}
	// else returnCode == NSAlertAlternateReturn, cancel
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
	BOOL succeeded = NO;
	OSStatus error = noErr;
	HFSUniStr255 *resourceForkName = (HFSUniStr255 *) NewPtrClear( sizeof(HFSUniStr255) );
	FSRef *fileRef = (FSRef *) NewPtrClear( sizeof(FSRef) );
	SInt16 fileRefNum = 0;
	
	// open fork with resources in it
	error = FSPathMakeRef( [fileName cString], fileRef, nil );
	error = FSGetResourceForkName( resourceForkName );
	SetResLoad( false );	// don't load "preload" resources
	error = FSOpenResourceFile( fileRef, resourceForkName->length, (UniChar *) &resourceForkName->unicode, fsRdPerm, &fileRefNum);
	if( error )				// try to open data fork instead
		error = FSOpenResourceFile( fileRef, 0, nil, fsRdPerm, &fileRefNum);
	else otherFork = resourceForkName;
	SetResLoad( true );		// restore resource loading as soon as is possible
	
	// read the resources
	if( fileRefNum && !error )
		succeeded = [self readResourceMap:fileRefNum];
	
	// tidy up loose ends
	if( !otherFork ) DisposePtr( (Ptr) resourceForkName );	// only delete if we're not saving it
	if( fileRefNum ) FSClose( fileRefNum );
	DisposePtr( (Ptr) fileRef );
	return succeeded;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)type
{
	return NO;
}

- (BOOL)readResourceMap:(SInt16)fileRefNum
{
	OSStatus error = noErr;
	unsigned short i, j, n;
	SInt16 oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	for( i = 1; i <= Count1Types(); i++ )
	{
		ResType resType;
		Get1IndType( &resType, i );
		n = Count1Resources( resType );
		for( j = 1; j <= n; j++ )
		{
			Str255	nameStr;
			long	sizeLong;
			short	resIDShort;
			short	attrsShort;
			Handle	resourceHandle;
			
			resourceHandle = Get1IndResource( resType, j );
			error = ResError();
			if( error != noErr )
			{
				UseResFile( oldResFile );
				return NO;
			}
			
			GetResInfo( resourceHandle, &resIDShort, &resType, nameStr );
			sizeLong = GetResourceSizeOnDisk( resourceHandle );
			attrsShort = GetResAttrs( resourceHandle );
			HLockHi( resourceHandle );
			
			// create the resource & add it to the array (am I leaking huge amounts of memory here, or are they dealloced automatically?)
			{
				NSString	*name		= [NSString stringWithCString:&nameStr[1] length:nameStr[0]];
				NSString	*type		= [NSString stringWithCString:(char *) &resType length:4];
				NSNumber	*size		= [NSNumber numberWithLong:sizeLong];
				NSNumber	*resID		= [NSNumber numberWithShort:resIDShort];
				NSNumber	*attributes	= [NSNumber numberWithShort:attrsShort];
				NSData		*data		= [NSData dataWithBytes:*resourceHandle length:sizeLong];
				Resource	*resource	= [Resource resourceOfType:type andID:resID withName:name andAttributes:attributes data:data ofLength:size];
				[resources addObject:resource];
				[resource autorelease];				
			}
			
			HUnlock( resourceHandle );
			ReleaseResource( resourceHandle );
		}
	}
	
	// save resource map and clean up
	UseResFile( oldResFile );
	return YES;
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type
{
	BOOL succeeded = NO;
	OSStatus error = noErr;
	FSRef *parentRef	= (FSRef *) NewPtrClear( sizeof(FSRef) );
	FSRef *fileRef		= (FSRef *) NewPtrClear( sizeof(FSRef) );
	FSSpec *fileSpec	= (FSSpec *) NewPtrClear( sizeof(FSSpec) );
	SInt16 fileRefNum = 0;
	
	// create and open file for writing
	error = FSPathMakeRef( [[fileName stringByDeletingLastPathComponent] cString], parentRef, nil );
 	if( otherFork )
	{
		unichar *uniname = (unichar *) NewPtrClear( sizeof(unichar) *256 );
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSCreateResourceFile( parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, nil, otherFork->length, (UniChar *) &otherFork->unicode, fileRef, fileSpec );
		if( !error )
			error = FSOpenResourceFile( fileRef, otherFork->length, (UniChar *) &otherFork->unicode, fsWrPerm, &fileRefNum);
	}
	else
	{
		unichar *uniname = (unichar *) NewPtrClear( sizeof(unichar) *256 );
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSCreateResourceFile( parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, nil, 0, nil, fileRef, fileSpec );
		if( !error )
			error = FSOpenResourceFile( fileRef, 0, nil, fsWrPerm, &fileRefNum);
	}
	
	// write resource array to file
	if( fileRefNum && !error )
		succeeded = [self writeResourceMap:fileRefNum];
	
	// tidy up loose ends
	if( fileRefNum ) FSClose( fileRefNum );
	DisposePtr( (Ptr) fileRef );
	return succeeded;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)type
{
	return NO;
}

- (BOOL)writeResourceMap:(SInt16)fileRefNum
{
	OSStatus error = noErr;
	unsigned long i;
	SInt16 oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	for( i = 0; i < [resources count]; i++ )
	{
		Resource *resource	= [resources objectAtIndex:i];
		
		Str255	nameStr;
		ResType	resType;
		short	resIDShort	= [[resource resID] shortValue];
		long	sizeLong	= [[resource size] longValue];
		short	attrsShort	= [[resource attributes] shortValue];
		Handle resourceHandle = NewHandleClear( sizeLong );
		
		nameStr[0] = [[resource name] cStringLength];
		BlockMoveData( [[resource name] cString], &nameStr[1], nameStr[0] );
		
		[[resource type] getCString:(char *) &resType maxLength:4];
		
		HLockHi( resourceHandle );
		[[resource data] getBytes:*resourceHandle];
		HUnlock( resourceHandle );
		
		AddResource( resourceHandle, resType, resIDShort, nameStr );
		if( ResError() == addResFailed )
		{
			NSLog( @"Saving failed; could not add resource \"%@\" of type %@ to file.", [resource name], [resource type] );
			error = addResFailed;
		}
		else
		{
			SetResAttrs( resourceHandle, attrsShort );
			ChangedResource( resourceHandle );
			UpdateResFile( fileRefNum );
		}
	}
	
	// save resource map and clean up
	UseResFile( oldResFile );
	return error? NO:YES;
}

- (NSOutlineView *)outlineView
{
	return outlineView;
}

- (ResourceDataSource *)dataSource
{
	return dataSource;
}

@end