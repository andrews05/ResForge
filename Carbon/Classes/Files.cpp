#include "Files.h"
#include "Application.h"
#include "FileWindow.h"
#include "ResourceObject.h"	// for saving inital resource data
#include "DataBrowser.h"	// for kDataBrowserForkItem constant
#include "Utility.h"
#include "Errors.h"
extern globals g;

/*	Convert an FSRef to an FSSpec:
		FSGetCatalogInfo( &fsref, kFSCatInfoNone, null, null, &spec, null );
	Get your application's FSSpec
		FSSpec spec;
		String name;
		ProcessInfoRec info;
		ProcessSerialNumber psn;
		GetCurrentProcess( &psn );
		info.processName = &name;
		info.processAppSpec = &spec;
		GetProcessInformation( psn, &info );
*/

/*** NAV OPEN FILE ***/
/*OSStatus NavOpenFile( void )
{
	OSStatus error = noErr;
	NavReplyRecord		reply;
	NavDialogOptions	dialogOptions;
	NavEventUPP			eventProc = NewNavEventUPP( NavEventFilter );
	NavPreviewUPP		previewProc = NewNavPreviewUPP( NavPreviewFilter );
	NavObjectFilterUPP	filterProc = NewNavObjectFilterUPP( NavFileFilter );
	
	// Initialize dialog options structure and set default values
	NavGetDefaultDialogOptions( &dialogOptions );
	dialogOptions.dialogOptionFlags = kNavNoTypePopup | kNavDontAutoTranslate | kNavDontAddTranslateItems | kNavAllowMultipleFiles | kNavAllowInvisibleFiles;
	BlockMoveData( g.appName, dialogOptions.clientName, sizeof(Str255) );
	
	// call the nav services routine
	error = NavGetFile( null, &reply, &dialogOptions, eventProc, previewProc, filterProc, null, null );
	DisposeNavEventUPP( eventProc );
	DisposeNavPreviewUPP( previewProc );
	DisposeNavObjectFilterUPP( filterProc );
	
	if( reply.validRecord && error == noErr )
	{
		if( g.useAppleEvents )
			error = AppleEventSendSelf( kCoreEventClass, kAEOpenDocuments, reply.selection );
#if !TARGET_API_MAC_CARBON
		else
		{
			// open the list of item(s):
			AEKeyword 	keyword;
			DescType 	descType;
			FSSpec		fileSpec;	
			Size 		actualSize;
			
			error = AEGetNthPtr( &(reply.selection), 1, typeFSS, &keyword, &descType, &fileSpec, sizeof(FSSpec), &actualSize );
			if( !error )	// if sucessful, open & read the file
				new FileWindow( &fileSpec );
*/ /*			SInt32	count;
			FSSpec	fileSpec;
			AEDesc	resultDesc;
			error = AECountItems( &(reply.selection), &count );
			if( !error )
				for( SInt32 n = 1; n <= count; n++ )
				{
					error = AEGetNthDesc( &(reply.selection), n, typeFSS, null, &resultDesc );
					if( !error )
					{
						HLock( (Handle) resultDesc.dataHandle );
						BlockMoveData( (void *) *resultDesc.dataHandle, &fileSpec, sizeof(FSSpec) );
						new FileWindow( &fileSpec );
						AEDisposeDesc( &resultDesc );
					}
				}
*/	/*	}
#endif
		
		// Always dispose of reply structure, resources, and descriptors
		error = NavDisposeReply( &reply );
	}
	return error;
}
*/

#if !TARGET_API_MAC_CARBON

/*** OPEN FILE ***/
OSStatus OpenFile( short vRefNum, long dirID, ConstStr255Param fileName )
{
	FSSpec fileSpec;
	FSMakeFSSpec( vRefNum, dirID, fileName, &fileSpec );
	new FileWindow( &fileSpec );
	return noErr;
}

/*** DISPLAY STANDARD FILE OPEN DIALOG ***/
OSStatus DisplayStandardFileOpenDialog( void )
{
	StandardFileReply	theReply;
	SFTypeList			typeList = { 0x0L };
	
	StandardGetFile( null, 0, typeList, &theReply );
	if( theReply.sfGood ) new FileWindow( &theReply.sfFile );
	return theReply.sfGood? noErr:userCanceledErr;
}

#endif

/*** OPEN A FILE DIALOG ***/
OSStatus DisplayOpenDialog( void )
{
	OSStatus			error = noErr;
	NavReplyRecord		reply;
	NavDialogOptions	dialogOptions;
	NavEventUPP			eventProc = NewNavEventUPP( NavEventFilter );
	NavPreviewUPP		previewProc = NewNavPreviewUPP( NavPreviewFilter );
	NavObjectFilterUPP	filterProc = NewNavObjectFilterUPP( NavFileFilter );
	NavTypeListHandle	typeList = null;
	
	NavGetDefaultDialogOptions( &dialogOptions );
	dialogOptions.dialogOptionFlags += kNavNoTypePopup;
	GetIndString( dialogOptions.clientName, kFileNameStrings, kStringResKnifeName );
	error = NavGetFile( null, &reply, &dialogOptions, eventProc, previewProc, filterProc, typeList, null);
	if( reply.validRecord || !error )
	{
		AEKeyword 	keyword;
		DescType 	descType;
		FSSpec		fileSpec;	
		Size 		actualSize;
		
		error = AEGetNthPtr( &(reply.selection), 1, typeFSS, &keyword, &descType, &fileSpec, sizeof(FSSpec), &actualSize );
		if( !error ) new FileWindow( &fileSpec );	// if sucessful, opens & reads the file
		NavDisposeReply( &reply );
	}
	else error = userCanceledErr;
	
	DisposeNavEventUPP( eventProc );
	DisposeNavPreviewUPP( previewProc );
	DisposeNavObjectFilterUPP( filterProc );
	return error;
}

/*** DISPLAY MODELESS GET FILE DIALOG ***/
OSStatus DisplayModelessGetFileDialog( void )
{
	OSStatus			error;
	NavEventUPP			eventProc = NewNavEventUPP( ModelessGetFileHandler );
	NavPreviewUPP		previewProc = null;
	NavObjectFilterUPP	filterProc = null;
	NavTypeListHandle	typeList = null;
	NavDialogCreationOptions options;
	error = NavGetDefaultDialogCreationOptions( &options );
	options.clientName = (CFStringRef) CFBundleGetValueForInfoDictionaryKey( CFBundleGetMainBundle(), kCFBundleNameKey );
	
	NavDialogRef dialog;
	error = NavCreateGetFileDialog( &options, typeList, eventProc, previewProc, filterProc, null, &dialog );
	error = NavDialogRun( dialog );
	if( error ) NavDialogDispose( dialog );
	return error;
}

/*** SAVE FILE DIALOG ***/
OSStatus FileWindow::DisplaySaveDialog( void )
{
	OSStatus			error = noErr;
	NavDialogOptions	options;
	NavEventUPP			eventProc = NewNavEventUPP( NavEventFilter );
	NavAskSaveChangesAction	action = g.quitting? kNavSaveChangesQuittingApplication : kNavSaveChangesClosingDocument;
	NavAskSaveChangesResult	result;
	
	NavGetDefaultDialogOptions( &options );
	GetWindowTitle( window, options.savedFileName );
//	GetIndString( options.clientName, kFileNameStrings, kStringAppName );
	NavAskSaveChanges( &options, action, &result, eventProc, null );
	
	switch( result )
	{
		case kNavAskSaveChangesSave:
			if( fileExists )	error = SaveFile( null );
			else				error = DisplaySaveAsDialog();
			break;
		
		case kNavAskSaveChangesDontSave:
			break;
		
		case kNavAskSaveChangesCancel:
			g.cancelQuit = true;
			g.quitting = false;		// bug: why can't I check for userCanceledErr instead?
			error = userCanceledErr;
			break;
	}
	
	DisposeNavEventUPP( eventProc );
	return error;
}

/*** DISPLAY MODELESS SAVE DIALOG ***/
OSStatus FileWindow::DisplayModelessAskSaveChangesDialog( void )
{
	OSStatus			error;
	NavEventUPP			eventProc = NewNavEventUPP( ModelessAskSaveChangesHandler );
/*	NavPreviewUPP		previewProc = null;
	NavObjectFilterUPP	filterProc = null;
	NavTypeListHandle	typeList = null;
*/	NavAskSaveChangesAction	action = g.quitting? kNavSaveChangesQuittingApplication : kNavSaveChangesClosingDocument;
	NavDialogCreationOptions options;
	error = NavGetDefaultDialogCreationOptions( &options );
	options.parentWindow = window;
	options.modality = kWindowModalityWindowModal;
	options.clientName = (CFStringRef) CFBundleGetValueForInfoDictionaryKey( CFBundleGetMainBundle(), kCFBundleNameKey );	// bug: are these two strings CFReleased? Should they be?
	options.saveFileName = CFStringCreateWithPascalString( null, fileSpec->name, CFStringGetSystemEncoding());				// bug: see above
	
	NavDialogRef dialog;
	error = NavCreateAskSaveChangesDialog( &options, action, eventProc, this, &dialog );
	error = NavDialogRun( dialog );
	return error;
}

/*** SAVE AS DIALOG ***/
OSStatus FileWindow::DisplaySaveAsDialog( void )
{
	OSStatus			error = noErr;
	NavReplyRecord		reply;
	NavDialogOptions	dialogOptions;
	NavEventUPP			eventProc = NewNavEventUPP( NavEventFilter );
	
	NavGetDefaultDialogOptions( &dialogOptions );
	GetWindowTitle( window, dialogOptions.savedFileName );
	GetIndString( dialogOptions.clientName, kFileNameStrings, kStringResKnifeName );
	error = NavPutFile( null, &reply, &dialogOptions, eventProc, kResourceFileType, kResKnifeCreator, null );
	if( reply.validRecord || !error )
	{
		AEKeyword 	keyword;
		DescType 	descType;
		FSSpec		savedSpec;	
		Size 		actualSize;
		
		// bug: does the next line only get the first selected file?
		error = AEGetNthPtr( &(reply.selection), 1, typeFSS, &keyword, &descType, &savedSpec, sizeof(FSSpec), &actualSize );
		if( !error )
		{
			if( reply.replacing ) error = FSpDelete( &savedSpec );
			if( !error )
			{
				error = SaveFile( &savedSpec );
				if ( !error )
					error = NavCompleteSave( &reply, kNavTranslateInPlace );
			}
			else if( error == fBsyErr )
			{
				DisplayError( kStringUnknownError, kExplanationUnknownError ); // read error
			}
		}
		NavDisposeReply( &reply );
	}
	else if( !error ) error = userCanceledErr;
		
	DisposeNavEventUPP( eventProc );
	return error;
}

/*** DISPLAY MODELESS PUT FILE DIALOG ***/
OSStatus FileWindow::DisplayModelessPutFileDialog( void )
{
	OSStatus			error;
	NavEventUPP			eventProc = NewNavEventUPP( ModelessPutFileHandler );
	NavDialogCreationOptions options;
	error = NavGetDefaultDialogCreationOptions( &options );
	options.parentWindow = window;
	options.modality = kWindowModalityWindowModal;
	options.clientName = (CFStringRef) CFBundleGetValueForInfoDictionaryKey( CFBundleGetMainBundle(), kCFBundleNameKey );
	options.saveFileName = CFStringCreateWithPascalString( null, fileSpec->name, CFStringGetSystemEncoding());
	
	NavDialogRef dialog;
	error = NavCreatePutFileDialog( &options, kResourceFileType, kResKnifeCreator, eventProc, this, &dialog );
	error = NavDialogRun( dialog );
	return error;
}

/*** DISPLAY REVERT FILE DIALOG ***/
OSStatus FileWindow::DisplayRevertFileDialog( void )
{
	OSStatus					error = noErr;
	NavDialogOptions			dialogOptions;
	NavEventUPP					eventProc = NewNavEventUPP( NavEventFilter );
	NavAskDiscardChangesResult	result;
	
	NavGetDefaultDialogOptions( &dialogOptions );
	GetWindowTitle( window, dialogOptions.savedFileName );
	NavAskDiscardChanges( &dialogOptions, &result, eventProc, null );
	
	switch( result )
	{
		case kNavAskDiscardChanges:
/*			error = CloseFile();
			if( error ) break;
			
			error = OpenFile();
			if( error ) break;
			
			error = ReadFile();
*/			break;
		
		case kNavAskDiscardChangesCancel:
			break;
	}
	
	DisposeNavEventUPP( eventProc );
	return error;
}

/*** DISPLAY MODELESS ASK DISCARD CHANGES DIALOG ***/
OSStatus FileWindow::DisplayModelessAskDiscardChangesDialog( void )
{
	OSStatus			error;
	NavEventUPP			eventProc = NewNavEventUPP( ModelessAskDiscardChangesHandler );
	NavDialogCreationOptions options;
	error = NavGetDefaultDialogCreationOptions( &options );
	options.parentWindow = window;
	options.modality = kWindowModalityWindowModal;
	options.clientName = (CFStringRef) CFBundleGetValueForInfoDictionaryKey( CFBundleGetMainBundle(), kCFBundleNameKey );
	options.saveFileName = CFStringCreateWithPascalString( null, fileSpec->name, CFStringGetSystemEncoding());
	
	NavDialogRef dialog;
	error = NavCreateAskDiscardChangesDialog( &options, eventProc, this, &dialog );
	error = NavDialogRun( dialog );
	return error;
}

  /*******************************/
 /* NAV SERVICES EVENT HANDLERS */
/*******************************/

#pragma mark -

/*** NAV SERVICES EVENT FILTER ***/
pascal void NavEventFilter( NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD )
{
	#pragma unused( callBackUD )
	switch( callBackSelector )
	{
		case kNavCBEvent:
			switch( cbRecord->eventData.eventDataParms.event->what )
			{
				default:
					break;
			}
			break;
		
/*		// Don't open file if it gets double-clicked (e.g. to add to an 'open' list instead)
		case kNavCBOpenSelection:
			NavCustomControl( callBackParms->context, (long) kNavCtlSetActionState, (void *) kNavDontOpenState );
			break;	*/
	}
}

/*** NAV SERVICES PREVIEW FILTER ***/
pascal Boolean NavPreviewFilter( NavCBRecPtr callBackParms, void *callBackUD )
{
	#pragma unused( callBackParms, callBackUD )
	return false;
}

/*** NAV SERVICES FILE FILTER ***/
pascal Boolean NavFileFilter( AEDescPtr theItem, void *info, void *callBackUD, NavFilterModes filterMode )
{
	#pragma unused( theItem, info, callBackUD, filterMode )
/*	do something useful here:
		count rsources & types
		give DF-based or RF-based info
		maybe something else?
*/	return true;
}

#pragma mark -

/*** MODELESS GET FILE HANDLER ***/
pascal void ModelessGetFileHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD )
{
	#pragma unused( callBackUD )
	OSStatus error = noErr;
	switch( callBackSelector )
	{	
		case kNavCBAccept:
//		case kNavCBUserAction:
		{	// open first selected file
			NavReplyRecord reply;
			error = NavDialogGetReply( cbRecord->context, &reply );
			if( reply.validRecord )
			{
				AEKeyword 	keyword;
				DescType 	descType;
				FSSpec		fileSpec;	
				Size 		actualSize;
				
				error = AEGetNthPtr( &(reply.selection), 1, typeFSS, &keyword, &descType, &fileSpec, sizeof(FSSpec), &actualSize );
				if( !error ) new FileWindow( &fileSpec );	// if sucessful, opens & reads the file
			}
			else SysBeep(0);
			NavDisposeReply( &reply );
		}	break;
		
		case kNavCBTerminate:
		{	// dispose of the dialog
			NavDialogDispose( cbRecord->context );
		}	break;
	}
}

/*** MODELESS ASK SAVE CHANGES HANDLER ***/
pascal void ModelessAskSaveChangesHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD )
{
	OSStatus error = noErr;
	FileWindowPtr file = (FileWindowPtr) callBackUD;
	switch( callBackSelector )
	{	
		case kNavCBUserAction:
		{	// open first selected file
			NavReplyRecord reply;
			error = NavDialogGetReply( cbRecord->context, &reply );
			if( reply.validRecord )
			{
				error = file->SaveFile( null );
			}
			else SysBeep(0);
			NavDisposeReply( &reply );
		}	break;
		
		case kNavCBTerminate:
		{	// dispose of the dialog
			NavDialogDispose( cbRecord->context );
		}	break;
	}
}

/*** MODELESS PUT FILE HANDLER ***/
pascal void ModelessPutFileHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD )
{
	OSStatus error = noErr;
//	FileWindowPtr file = (FileWindowPtr) callBackUD;
	switch( callBackSelector )
	{	
		case kNavCBUserAction:
		{	// open first selected file
			NavReplyRecord reply;
			error = NavDialogGetReply( cbRecord->context, &reply );
			if( reply.validRecord )
			{
				;
			}
			else SysBeep(0);
			NavDisposeReply( &reply );
		}	break;
		
		case kNavCBTerminate:
		{	// dispose of the dialog
			NavDialogDispose( cbRecord->context );
		}	break;
	}
}

/*** MODELESS ASK DISCARD CHANGES HANDLER ***/
pascal void ModelessAskDiscardChangesHandler( const NavEventCallbackMessage callBackSelector, NavCBRecPtr cbRecord, NavCallBackUserData callBackUD )
{
	OSStatus error = noErr;
//	FileWindowPtr file = (FileWindowPtr) callBackUD;
	switch( callBackSelector )
	{	
		case kNavCBUserAction:
		{	// open first selected file
			NavReplyRecord reply;
			error = NavDialogGetReply( cbRecord->context, &reply );
			if( reply.validRecord )
			{
				;
			}
			else SysBeep(0);
			NavDisposeReply( &reply );
		}	break;
		
		case kNavCBTerminate:
		{	// dispose of the dialog
			NavDialogDispose( cbRecord->context );
		}	break;
	}
}

  /*********************/
 /* READING & WRITING */
/*********************/

#pragma mark -

/*** READ RESOURCE FORK ***/
OSStatus FileWindow::ReadResourceFork( void )
{
	// open file for reading
	OSStatus error = noErr;
	SInt16 oldResFile = CurResFile();
	SetResLoad( false );	// don't load "preload" resources
	SInt16 refNum = FSpOpenResFile( fileSpec, fsRdPerm );
	SetResLoad( true );
	if( !refNum ) return resFNotFound;
	UseResFile( refNum );
	error = ResError();
	if( error )	// no resource map in resource fork, try in data fork before alerting user
		DebugError( "\pResource map not present in resource fork", error );
	// fork-independant resource reading routine
	else error = ReadResourceMap();
	rfBased = error? false:true;
	
	// tidy up loose ends
	UseResFile( oldResFile );
	FSClose( refNum );
	return error;
}

/*** READ DATA FORK ***/
OSStatus FileWindow::ReadDataFork( OSStatus rfError )
{
	OSStatus error = rfError;
	if( error )		// error occoured reading resource map from resource fork, try reading map from data fork instead
	{
#if TARGET_API_MAC_CARBON
		FSRef fileRef;
		SInt16 refNum;
		SInt16 oldResFile = CurResFile();
		error = FSpMakeFSRef( fileSpec, &fileRef );
		if( error )
		{
			DebugError( "\pFSpMakeFSRef error", error );
			return error;
		}
		if( FSOpenResourceFile == (void *) kUnresolvedCFragSymbolAddress )
		{
			DisplayError( "\pCarbonLib version too old", "\pThe version of CarbonLib you have installed won't let you view files whose resources are stored in the data fork. Please update to version 1.3 GM of CarbonLib, available from http://www.apple.com/" );
			error = paramErr;
			return error;
		}
		SetResLoad( false );	// don't load "preload" resources
		error = FSOpenResourceFile( &fileRef, 0, null, fsRdPerm, &refNum );
		SetResLoad( true );
		if( error || !refNum )
		{
			DisplayError( "\pThis file is corrupt", "\pSorry, but you will not be able to open it. You should replace it with a backÑup. FSOpenResourceFile()" );
			return error? error:resFNotFound;
		}
		UseResFile( refNum );
		
		// fork-independant resource reading routine
		error = ReadResourceMap();
		
		// tidy up loose ends
		UseResFile( oldResFile );
		FSClose( refNum );
#endif
		return error;
	}
	else			// no error occoured reading resource map from resource fork, read data fork as byte stream
	{
		// open file for reading
		SInt16 refNum;
		error = FSpOpenDF( fileSpec, fsRdPerm, &refNum );
		if( error )
		{
			DisplayError( "\pData fork could not be read", "\pThis file appears to be corrupted. Although the resources could be read in correctly, the data fork could not be found. Please run Disk First Aid to correct the problem." );
			return error;	
		}
		ResourceObjectPtr current = (ResourceObjectPtr) NewPtrClear( sizeof(ResourceObject) );
		if( !current )
		{
			DisplayError( "\pNot enough memory to read data fork", "\pPlease quit other applications and try again." );
			FSClose( refNum );
			return error;	
		}
		
		current->number = kDataBrowserDataForkItem;	// ID of fork in dataBrowser
		*current->name = 0x00;
		current->type = 0x00000000;
		current->resID = 0;
		GetEOF( refNum, &current->size );
		current->attribs = 0;
		current->nameIconRgn = NewRgn();
		current->file = this;
		current->dataFork = true;
		
		// get new handle
		current->retainCount = 1;
		current->data = NewHandleClear( current->size );
		if( !current->data || MemError() )
		{
			DisplayError( "\pNot enough memory to read data fork", "\pPlease quit other applications and try again." );
			FSClose( refNum );
			return memFullErr;
		}
		
		// read data fork
		HLock( current->data );
		error = FSRead( refNum, &current->size, *current->data );
		HUnlock( current->data );
		if( error )
		{
			DisplayError( "\pFailed to read data fork.", "\pA mysterious error occured reading the data fork. The record saying how long the file is has probably been corrupted. You should run Disk First Aid to repair the dis." );
			FSClose( refNum );
			return error;
		}
		
		current->next = resourceMap;
		resourceMap = current;
		FSClose( refNum );
		return error;
	}
}

/*** READ RESOURCE MAP ***/
OSStatus FileWindow::ReadResourceMap( void )
{
	OSStatus error = noErr;
	
	// set up variables & first resource record
	numResources = 0;
	numTypes = Count1Types();
	resourceMap = (ResourceObjectPtr) NewPtrClear( sizeof(ResourceObject) );
//	resourceMap = new ResourceObject( this );
	ResourceObjectPtr current = resourceMap;
	
	for( unsigned short i = 1; i <= numTypes; i++ )
	{
		// read in each data type
		ResType type;
		Get1IndType( &type, i );
		UInt16 n = Count1Resources( type );
		for( UInt16 j = 1; j <= n; j++ )
		{
			// get resource info
//			SetResLoad( false );
			current->data = Get1IndResource( type, j );
			error = ResError();
//			SetResLoad( true );
			if( MemError() )
			{
				DisplayError( "\pNot enough memory to read all resources", "\pPlease quit other applications and try again." );
				DisposePtr( (Ptr) current );
				return memFullErr;
			}
			if( !current->Data() || error != noErr )
			{
				DisplayError( "\pResources are damaged, proceed with extreme caution!" );
				// bug: dialog should have "continue", "stop" and "quit" buttons, stop being default
				DisposePtr( (Ptr) current );
			//	delete current;
				return error;	// bug: what should I be doing here?
			}
			current->number = numResources + j;	// ID of resource in dataBrowser
			GetResInfo( current->Data(), &current->resID, &current->type, current->name );
			current->size = GetResourceSizeOnDisk( current->Data() );
			current->attribs = GetResAttrs( current->Data() );
			current->file = this;
			current->dataFork = false;
			DetachResource( current->Data() );	// bug: this needs to be here so calling AddResource() when saving will work, but if ResLoad() was off above, it will kill the only link between the Handle and the resource.
			
			if( i != numTypes || j != n )	// if this isn't the last resourceÉ
			{
				// Émove on to the next one
				current->next = (ResourceObjectPtr) NewPtrClear( sizeof(ResourceObject) );
//				current->next = new ResourceObject( this );
				current = current->next;
			}
		}
		numResources += n;
	}
	return error;
}

/*** SAVE FILE ***/
OSStatus FileWindow::SaveFile( FSSpecPtr saveSpec )
{
	OSStatus error;
	
	if( saveSpec == null )		// we're straight saving the file, use a temp file, then switch
	{
		// set up file name
		Str255 countStr;	// bug: this is not initalised before being used
		Str255 tempFileName = "\pResKnife Temporary File ";
		NumToString( ++g.tempCount, (StringPtr) countStr );
		AppendPString( tempFileName, countStr );
		
		// create temporary file spec
		SInt32 dirID;
		SInt16 vRefNum;		// Always create the temporary file on the same volume as the file we're saving, otherwise FSpExchangeFiles() won't work
		OSStatus error = FindFolder( fileSpec->vRefNum, /*kTemporaryFolderType*/ kDesktopFolderType, kCreateFolder, &vRefNum, &dirID );
		if( error ) DebugError( "\pFindFolder returned error.", error );
		error = FSMakeFSSpec( vRefNum, dirID, tempFileName, tempSpec );
		if( error == noErr )
		{
			DisplayError( "\pFile already exists", "\pThe temporary file used by ResKnife to protect your data already exists, try saving again. If the problem persists, flush your temporary items folder with a utility such as Eradicator." );
			return error;
		}
		else if( error != fnfErr && error != dirNFErr )
		{
			DebugError( "\pError calling FSMakeFSSpec from FileWindow::SaveFile.", error );
			return error;
		}
	}
	else						// we're doing a 'save as', no need for temp file
	{							//	if we created one, then FSpExchange wouldn't work
		tempSpec = saveSpec;
	}
	
	// save plain DF if present
	ResourceObjectPtr current = resourceMap;
	if( rfBased && current->RepresentsDataFork() )		// requires data fork to be first item in list
	{
		// create data fork
		FSpCreate( tempSpec, kResKnifeCreator, kResourceFileType, smSystemScript );
		
		// open file for writing
		SInt16 refNum;
		error = FSpOpenDF( tempSpec, fsWrPerm, &refNum );
		if( error )
		{
			DisplayError( "\pData fork could not be read", "\pThis file appears to be corrupted. Although the resources could be read in correctly, the data fork could not be found. Please run Disk First Aid to correct the problem." );
			return error;	
		}
		
		// save byte stream
		SInt8 state = HGetState( resourceMap->Data() );
		HLock( current->Data() );
		SInt32 size = current->Size();
		SetEOF( refNum, size );
		error = FSWrite( refNum, &size, (Ptr) *current->Data() );
		HSetState( current->Data(), state );
		FSClose( refNum );
	}
	else if( !rfBased && current->RepresentsDataFork() )
	{
		DisplayError( "\pData fork present with DF-based resource file." );
	}
	else if( rfBased )
	{
		DisplayError( "\pTried to save resource fork based file, but no data fork could be found" );
	}
	
	// save resource map in specified fork
	if( rfBased )
	{
		SInt16 oldResFile = CurResFile();
		FSpCreateResFile( tempSpec, kResKnifeCreator, kResourceFileType, smSystemScript );
		SInt16 tempRef = FSpOpenResFile( tempSpec, fsWrPerm );
		UseResFile( tempRef );
		error = SaveResourceMap();
		UseResFile( oldResFile );
		CloseResFile( tempRef );
		error = ResError();
		if( error )
		{
			DebugError( "\pError calling CloseResFile.", error );
			return error;
		}
	}
	else
	{
		FSRef fileRef;
		SInt16 refNum;
		SInt16 oldResFile = CurResFile();
		error = FSpMakeFSRef( tempSpec, &fileRef );
		if( error )
		{
			DebugError( "\pFSpMakeFSRef error", error );
			return error;
		}
		if( FSOpenResourceFile == (void *) kUnresolvedCFragSymbolAddress )
		{
			DisplayError( "\pCarbonLib version too old", "\pThe version of CarbonLib you have installed won't let you save resources into the data fork. Please update to version 1.3.1 of CarbonLib, available from http://www.apple.com/" );
			error = paramErr;
			return error;
		}
/*		error = FSCreateResourceFile( &fileRef, );
										const FSRef *          parentRef,
										UniCharCount           nameLength,
										const UniChar *        name,
										FSCatalogInfoBitmap    whichInfo,
										const FSCatalogInfo *  catalogInfo,          // can be NULL
										UniCharCount           forkNameLength,
										const UniChar *        forkName,             // can be NULL
										FSRef *                newRef,               // can be NULL
										FSSpec *               newSpec);             // can be NULL
		
		if( error )
		{
			DisplayError( "\pFile could not be created", "\pThe file to save your resources into could not be created. FSCreateResourceFile()" );
			return error? error:resFNotFound;
		}
*/		error = FSOpenResourceFile( &fileRef, 0, null, fsRdPerm, &refNum );
		if( error || !refNum )
		{
			DisplayError( "\pFile could not be created", "\pThe file to save your resources into could not be created. FSOpenResourceFile()" );
			return error? error:resFNotFound;
		}
		UseResFile( refNum );
		error = SaveResourceMap();
		UseResFile( oldResFile );
		CloseResFile( refNum );
		error = ResError();
		if( error )
		{
			DebugError( "\pError calling CloseResFile.", error );
			return error;
		}
	}
	
	// switch file for temp if we did a regular save
	if( saveSpec == null )
	{
		// swap the temporary file for the real one
		error = FSpExchangeFiles( tempSpec, fileSpec );		// bug: this will fail on non HFS/HFS+ file systems - therefore file will not save
		if( error )
		{
			DebugError( "\pError calling FSpExchangeFiles.", error );
			return error;
		}
		error = FSpDelete( tempSpec );
		if( error )
		{
			DebugError( "\pError calling FSpDelete.", error );
		}
		
		// file is no longer dirty
		fileDirty = false;
		SetWindowModified( window, fileDirty );
	}
	return error;
}

/*** SAVE RESOURCE MAP ***/
OSStatus FileWindow::SaveResourceMap( void )
{
	OSStatus error = noErr;
	// save resources from memory to the temp file
	ResourceObjectPtr current = resourceMap;
	if( current->RepresentsDataFork() == true )
		current = current->Next();	// skip data fork
	while( current )
	{
		// save resource
		AddResource( current->Data(), current->Type(), current->ID(), current->Name() );
		if( ResError() == addResFailed )
		{
			DisplayError( "\pSaving Failed", "\pCould not add resources to file." );
			current = null;
			error = addResFailed;
		}
		else
		{
			SetResAttrs( current->Data(), current->Attributes() );
			ChangedResource( current->Data() );
			
			// clean up & move on
			DetachResource( current->Data() );
			current = current->Next();
		}
	}
	return error;
}