#include "DataBrowser.h"
#include "ResourceObject.h"
#include "InspectorWindow.h"
#include "Errors.h"
#include "Utility.h"	// for TypeToCFString() et cetera

extern globals g;

#if TARGET_API_MAC_CARBON	// CarbonLib 1.1+ or Public Beta only

/*** INITALISE DATA BROWSER ***/
OSStatus FileWindow::InitDataBrowser( void )
{
	OSStatus error = noErr;
	
	// get the db control - compatable with both CarbonLib and nib based versions
	ControlID id = { kDataBrowserSignature, 0 };
	GetControlByID( window, &id, &dataBrowser );
	
	// set control ref to FileWindow
	SetControlReference( dataBrowser, (long) this );
	
	// turn off frame and focus
	Boolean frame = false;
	SetControlData( dataBrowser, kControlNoPart, kControlDataBrowserIncludesFrameAndFocusTag, sizeof(Boolean), &frame );
	
#if !USE_NIBS
	// add empty columns
	AddDataBrowserColumn( dataBrowser, kDBNameColumn, 0 );	// save column order into prefs file: Get/SetDataBrowserUserState()
	AddDataBrowserColumn( dataBrowser, kDBTypeColumn, 1 );
	AddDataBrowserColumn( dataBrowser, kDBIDColumn, 2 );
	AddDataBrowserColumn( dataBrowser, kDBSizeColumn, 3 );
#endif
	
	// add callbacks
	DataBrowserCallbacks theCallbacks;
	theCallbacks.version = kDataBrowserLatestCallbacks;
	InitDataBrowserCallbacks( &theCallbacks );
	theCallbacks.u.v1.itemDataCallback			= NewDataBrowserItemDataUPP( DataBrowserItemData );
	theCallbacks.u.v1.itemCompareCallback		= NewDataBrowserItemCompareUPP( SortDataBrowser );
	theCallbacks.u.v1.itemNotificationCallback	= NewDataBrowserItemNotificationUPP( DataBrowserMessage );
	theCallbacks.u.v1.addDragItemCallback		= NewDataBrowserAddDragItemUPP( DataBrowserAddDragItem );
	theCallbacks.u.v1.acceptDragCallback		= NewDataBrowserAcceptDragUPP( DataBrowserAcceptDrag );
	theCallbacks.u.v1.receiveDragCallback		= NewDataBrowserReceiveDragUPP( DataBrowserReceiveDrag );
	theCallbacks.u.v1.postProcessDragCallback	= NewDataBrowserPostProcessDragUPP( DataBrowserPostProcessDrag );
	SetDataBrowserCallbacks( dataBrowser, &theCallbacks );
	
	// setup rest of browser, inc. adding all resources
	DataBrowserItemID item;
	for( UInt32 n = 1; n <= numResources; n++ )
	{
		item = n;
		error = AddDataBrowserItems( dataBrowser, kDataBrowserNoItem, 1, &item, kDataBrowserItemNoProperty );
		if( error ) DebugError( "\pError occoured adding resource to data browser." );
	}
	
	// add data fork if present
	if( resourceMap->RepresentsDataFork() )	// requires data fork to be first in chain
	{
		item = kDataBrowserDataForkItem;	// curently 0xFFFFFFFF
		error = AddDataBrowserItems( dataBrowser, kDataBrowserNoItem, 1, &item, kDataBrowserItemNoProperty );
		if( error ) DebugError( "\pError occoured adding data fork to data browser." );
	}
	
	SetDataBrowserSortProperty( dataBrowser, kDBTypeColumn );
	SetDataBrowserTableViewRowHeight( dataBrowser, 16 +2 );
	SetDataBrowserListViewDisclosureColumn( dataBrowser, kDBNameColumn, true );
	
	// set up drag tracking
	SetControlDragTrackingEnabled( dataBrowser, true );
	return error;
}

/*** ADD DATA BROWSER COLUMN ***/
void AddDataBrowserColumn( ControlRef browser, DataBrowserPropertyID column, UInt16 position )
{
	DataBrowserListViewColumnDesc columnDesc;
	switch( column )
	{
		case kDataBrowserNameColumn:
			columnDesc.propertyDesc.propertyID		= kDataBrowserNameColumn;
			columnDesc.propertyDesc.propertyType	= kDataBrowserIconAndTextType;
			columnDesc.propertyDesc.propertyFlags	= kDataBrowserListViewDefaultColumnFlags | kDataBrowserListViewSelectionColumn;
			
			columnDesc.headerBtnDesc.version		= kDataBrowserListViewLatestHeaderDesc;
			columnDesc.headerBtnDesc.minimumWidth	= 150;
			columnDesc.headerBtnDesc.maximumWidth	= 250;
			columnDesc.headerBtnDesc.titleOffset	= 0;
			columnDesc.headerBtnDesc.titleString	= CFSTR("Resource Name");	// these should be resources for ease of localisation
			columnDesc.headerBtnDesc.initialOrder	= kDataBrowserOrderIncreasing;
			columnDesc.headerBtnDesc.btnFontStyle.font	= kControlFontViewSystemFont;
			columnDesc.headerBtnDesc.btnFontStyle.just	= teFlushDefault;
			columnDesc.headerBtnDesc.btnFontStyle.style	= normal;
			
			columnDesc.headerBtnDesc.btnContentInfo.contentType	= kControlContentTextOnly;
			break;
		
		case kDataBrowserTypeColumn:
			columnDesc.propertyDesc.propertyID		= kDataBrowserTypeColumn;
			columnDesc.propertyDesc.propertyType	= kDataBrowserTextType;
			columnDesc.propertyDesc.propertyFlags	= kDataBrowserListViewDefaultColumnFlags;
			
			columnDesc.headerBtnDesc.version		= kDataBrowserListViewLatestHeaderDesc;
			columnDesc.headerBtnDesc.minimumWidth	= (g.systemVersion < kMacOSX)? 56:72;
			columnDesc.headerBtnDesc.maximumWidth	= columnDesc.headerBtnDesc.minimumWidth;
			columnDesc.headerBtnDesc.titleOffset	= 0;
			columnDesc.headerBtnDesc.titleString	= CFSTR("Type");	// these should be resources for ease of localisation
			columnDesc.headerBtnDesc.initialOrder	= kDataBrowserOrderIncreasing;
			
			columnDesc.headerBtnDesc.btnFontStyle.font	= kControlFontViewSystemFont;
			columnDesc.headerBtnDesc.btnFontStyle.just	= teFlushRight;
			columnDesc.headerBtnDesc.btnFontStyle.style	= normal;
			columnDesc.headerBtnDesc.btnContentInfo.contentType = kControlContentTextOnly;
			break;
		
		case kDataBrowserIDColumn:
			columnDesc.propertyDesc.propertyID		= kDataBrowserIDColumn;
			columnDesc.propertyDesc.propertyType	= kDataBrowserTextType;
			columnDesc.propertyDesc.propertyFlags	= kDataBrowserListViewDefaultColumnFlags;
			
			columnDesc.headerBtnDesc.version		= kDataBrowserListViewLatestHeaderDesc;
			columnDesc.headerBtnDesc.minimumWidth	= (g.systemVersion < kMacOSX)? 56:72;
			columnDesc.headerBtnDesc.maximumWidth	= columnDesc.headerBtnDesc.minimumWidth;
			columnDesc.headerBtnDesc.titleOffset	= 0;
			columnDesc.headerBtnDesc.titleString	= CFSTR("ID");	// these should be resources for ease of localisation
			columnDesc.headerBtnDesc.initialOrder	= kDataBrowserOrderIncreasing;
			
			columnDesc.headerBtnDesc.btnFontStyle.font	= kControlFontViewSystemFont;
			columnDesc.headerBtnDesc.btnFontStyle.just	= teFlushRight;
			columnDesc.headerBtnDesc.btnFontStyle.style	= normal;
			columnDesc.headerBtnDesc.btnContentInfo.contentType = kControlContentTextOnly;
			break;
		
		case kDataBrowserSizeColumn:
			columnDesc.propertyDesc.propertyID		= kDataBrowserSizeColumn;
			columnDesc.propertyDesc.propertyType	= kDataBrowserTextType;
			columnDesc.propertyDesc.propertyFlags	= kDataBrowserListViewDefaultColumnFlags;
			
			columnDesc.headerBtnDesc.version		= kDataBrowserListViewLatestHeaderDesc;
			columnDesc.headerBtnDesc.minimumWidth	= (g.systemVersion < kMacOSX)? 56:72;
			columnDesc.headerBtnDesc.maximumWidth	= columnDesc.headerBtnDesc.minimumWidth;
			columnDesc.headerBtnDesc.titleOffset	= 0;
			columnDesc.headerBtnDesc.titleString	= CFSTR("Size");	// these should be resources for ease of localisation
			columnDesc.headerBtnDesc.initialOrder	= kDataBrowserOrderIncreasing;
			
			columnDesc.headerBtnDesc.btnFontStyle.font	= kControlFontViewSystemFont;
			columnDesc.headerBtnDesc.btnFontStyle.just	= teFlushRight;
			columnDesc.headerBtnDesc.btnFontStyle.style	= normal;
			columnDesc.headerBtnDesc.btnContentInfo.contentType = kControlContentTextOnly;
			break;
	}
	
	// create column and make respond to sorting
	AddDataBrowserListViewColumn( browser, &columnDesc, position );
}

/*** HANDLE ITEM DATA I/O ***/
pascal OSStatus DataBrowserItemData( ControlRef browser, DataBrowserItemID itemID, DataBrowserPropertyID property, DataBrowserItemDataRef itemData, Boolean setValue )
{
	#pragma unused( setValue )
	OSStatus result = noErr;
	if( setValue ) return result;
	FileWindowPtr file = (FileWindowPtr) GetControlReference( browser );
	ResourceObjectPtr resource = file->GetResource( itemID );
	
	if( resource == null )
		DebugError( "\pNull resource returned within DataBrowserItemData()" );
	
	switch( property )
	{
		case kDataBrowserItemIsEditableProperty:
			if( true )	// should item be editable? (i.e. is it a name, ID or type?)
				SetDataBrowserItemDataBooleanValue( itemData, true );
			break;
		
		case kDataBrowserItemIsContainerProperty:
			if( resource->Type() == kIconFamilyType )
				SetDataBrowserItemDataBooleanValue( itemData, true );
			break;
		
		case kDBNameColumn:
		{	// icon Ñ no resource for the icon!
			IconRef theIcon = null;
#if !USE_NIBS
			if( itemID != kDataBrowserDataForkItem )
			{
				Str255 iconString;
				TypeToPString( resource->Type(), iconString );
				IconFamilyHandle iconFamily = (IconFamilyHandle) Get1NamedResource( kIconFamilyType, iconString );
				if( iconFamily )
				{
					RegisterIconRefFromIconFamily( kResKnifeCreator, resource->Type(), iconFamily, &theIcon );
					ReleaseResource( (Handle) iconFamily );	// when dragging a rect this call caused other columns not to be displayed !?!
				}
			}
#endif
			if( theIcon == null )
				GetIconRef( kOnSystemDisk, kResKnifeCreator, kResourceFileType, &theIcon );
			SetDataBrowserItemDataIcon( itemData, theIcon );
			ReleaseIconRef( theIcon );
		
			// resource name
			CFStringRef nameCFStr;
			if( itemID == kDataBrowserDataForkItem )
			{
#if USE_NIBS	// OS 9 version is not bundled at the present time
				nameCFStr = CFBundleCopyLocalizedString( CFBundleGetMainBundle(), CFSTR("Data Fork"), null, null );	// bug: doesn't actually get localized string!
#else
				nameCFStr = CFSTR("Data Fork");
#endif
				SetDataBrowserItemDataRGBColor( itemData, &g.textColour );
			}
			else if( *resource->Name() == 0x00 )
			{
#if USE_NIBS	// OS 9 version is not bundled at the present time
				nameCFStr = CFBundleCopyLocalizedString( CFBundleGetMainBundle(), CFSTR("Untitled Resource"), null, null );	// bug: doesn't actually get localized string!
#else
				nameCFStr = CFSTR("Untitled Resource");
#endif
				SetDataBrowserItemDataRGBColor( itemData, &g.textColour );
			}
			else nameCFStr = CFStringCreateWithPascalString( CFAllocatorGetDefault(), resource->Name(), kCFStringEncodingMacRoman );
			SetDataBrowserItemDataText( itemData, nameCFStr );
#if USE_NIBS	// OS 9 uses CFSTR()
			CFRelease( nameCFStr );
#endif
		}	break;
		
		case kDBTypeColumn:
		{	// resource type
			if( itemID == kDataBrowserDataForkItem )
			{
				SetDataBrowserItemDataText( itemData, CFSTR("-") );
			}
			else
			{
				CFStringRef typeString;
				TypeToCFString( resource->Type(), &typeString );
				SetDataBrowserItemDataText( itemData, typeString );
				CFRelease( typeString );
			}
		}	break;
		
		case kDBIDColumn:
		{	// resource ID
			if( itemID == kDataBrowserDataForkItem )
			{
				SetDataBrowserItemDataText( itemData, CFSTR("-") );
			}
			else
			{
				SInt16 id = resource->ID();
				Str255 idPString;
				NumToString( id, (StringPtr) &idPString );
				CFStringRef idString = CFStringCreateWithPascalString( CFAllocatorGetDefault(), idPString, kCFStringEncodingMacRoman );
				SetDataBrowserItemDataText( itemData, idString );
				CFRelease( idString );
			}
		}	break;
		
		case kDBSizeColumn:
		{	SInt32 size = resource->Size();
			UInt8 power = 0, remainder = 0;
			Str255 sizePString, frac;
			while( size >= 1024 && power <= 30 )
			{
				power += 10;	// 10 == KB, 20 == MB, 30 == GB
				remainder = (UInt8) ((size % 1024) / 102.4);		// 102.4 gives one dp, 10.24 would give two dps, 1.024 would give three dps
				size /= 1024;
			}
			NumToString( (long) size, (StringPtr) &sizePString );
			NumToString( remainder, (StringPtr) &frac );
			if( power )		// some division has occoured
			{
				if( sizePString[0] < 3 && remainder > 0 )
				{
										AppendPString( (unsigned char *) &sizePString, "\p." );		// bug: should be a comma on european systems
										AppendPString( (unsigned char *) &sizePString, (unsigned char *) &frac );
				}
				if( power == 10 )		AppendPString( (unsigned char *) &sizePString, "\p KB" );
				else if( power == 20 )	AppendPString( (unsigned char *) &sizePString, "\p MB" );
				else if( power == 30 )	AppendPString( (unsigned char *) &sizePString, "\p GB" );	// everything bigger will be given in GB
			}
			CFStringRef sizeString = CFStringCreateWithPascalString( CFAllocatorGetDefault(), sizePString, kCFStringEncodingMacRoman );
			SetDataBrowserItemDataText( itemData, sizeString );
			CFRelease( sizeString );
		}	break;
		
		default:
			result = errDataBrowserPropertyNotSupported;
			break;
	}
	return result;
}

/*** SORT DATA BROWSER ***/
pascal Boolean SortDataBrowser( ControlRef browser, DataBrowserItemID itemOne, DataBrowserItemID itemTwo, DataBrowserPropertyID sortProperty )
{
	short result;
	Str255 typeOne, typeTwo;
	StringPtr nameOne, nameTwo;
	FileWindowPtr file = (FileWindowPtr) GetControlReference( browser );
	
	// send data fork to top regardless of property
	if( itemOne == kDataBrowserDataForkItem ) return true;
	if( itemTwo == kDataBrowserDataForkItem ) return false;
	
	// validate data browser item IDs
	if( itemOne <= kDataBrowserNoItem || itemOne > file->GetResourceCount() )
	{
		DebugError( "\psort item one was invalid" );
		return false;
	}
	if( itemTwo <= kDataBrowserNoItem || itemTwo > file->GetResourceCount() )
	{
		DebugError( "\psort item two was invalid" );
		return false;
	}
	
	// get resource corrisponding to item ID
	ResourceObjectPtr resourceOne = file->GetResource( itemOne );
	ResourceObjectPtr resourceTwo = file->GetResource( itemTwo );
	if( resourceOne == null || resourceTwo == null )
		DebugError( "\pNull resource returned within SortDataBrowser()" );
	
	// sort resources according to property user has selected
	switch( sortProperty )
	{
		case kDBNameColumn:
			nameOne = resourceOne->Name();
			nameTwo = resourceTwo->Name();
			result = CompareString( nameOne, nameTwo, null );
			return result < 0;
		
		case kDBTypeColumn:
			TypeToPString( resourceOne->Type(), typeOne );
			TypeToPString( resourceTwo->Type(), typeTwo );
			result = CompareString( typeOne, typeTwo, null );
			return result < 0;
		
		case kDBIDColumn:
			return resourceOne->ID() < resourceTwo->ID();
		
		case kDBSizeColumn:
			return resourceOne->Size() < resourceTwo->Size();
		
		case kDataBrowserItemNoProperty:	// this is valid when first constructing the data browser
//			DebugError( "\pkDataBrowserItemNoProperty passed to sort function" );
			return false;
			
		default:
			DebugError( "\pInvalid sort property given" );
			return false;
	}
	return false;
}

/*** DATA BROWSER MESSAGE ***/
pascal void DataBrowserMessage( ControlRef browser, DataBrowserItemID itemID, DataBrowserItemNotification message/*, DataBrowserItemDataRef itemData*/ )
{
	#pragma unused( itemID/*, itemData*/ )
	FileWindowPtr file = (FileWindowPtr) GetControlReference( browser );
	switch( message )
	{
		case kDataBrowserItemDoubleClicked:
		{	KeyMap	theKeys;
			Boolean	shiftKeyDown = false,
					optionKeyDown = false,
					controlKeyDown = false;
			GetKeys( theKeys );
			if( theKeys[1] & (shiftKey >> shiftKeyBit) )	shiftKeyDown = true;
			if( theKeys[1] & (optionKey >> shiftKeyBit) )	optionKeyDown = true;
			if( theKeys[1] & (controlKey >> shiftKeyBit) )	controlKeyDown = true;
			if( optionKeyDown )			file->OpenResource( itemID, kMenuCommandOpenHex );
			else if( controlKeyDown )	file->OpenResource( itemID, kMenuCommandOpenTemplate );
			else						file->OpenResource( itemID, kMenuCommandOpenDefault );
		}	break;
		
		case kDataBrowserItemSelected:
		case kDataBrowserItemDeselected:
		case kDataBrowserSelectionSetChanged:
//			file->SetHeaderText();
			if( g.inspector )
				g.inspector->Update();
			break;
		
		case kDataBrowserEditStarted:
		case kDataBrowserEditStopped:
		case kDataBrowserItemAdded:
		case kDataBrowserItemRemoved:
		case kDataBrowserContainerOpened:
		case kDataBrowserContainerClosing:
		case kDataBrowserContainerClosed:
		case kDataBrowserContainerSorting:
		case kDataBrowserContainerSorted:
		case kDataBrowserTargetChanged:
		case kDataBrowserUserStateChanged:
			break;
	}
}

/*** ADD DRAG ITEM ***/
pascal Boolean DataBrowserAddDragItem( ControlRef browser, DragRef drag, DataBrowserItemID item, DragItemRef *itemRef )
{
	#pragma unused( item )
	
	// if drag already has phfs flavour, don't add another
	UInt16 numFlavours;
	CountDragItemFlavors( drag, *itemRef, &numFlavours );
	if( numFlavours > 0 ) return true;
	
	// add 'create file' callback
	if( itemRef )	*itemRef	= ItemReference( item );
	FlavorFlags		flags		= flavorNotSaved;
	DragSendDataUPP	sendData	= NewDragSendDataUPP( SendPromisedFile );
	SetDragSendProc( drag, sendData, browser );
	
	// setup imaginary file
	PromiseHFSFlavor			promisedFile;
	promisedFile.fileType		= kResourceFileType;
	promisedFile.fileCreator	= kResKnifeCreator;
	promisedFile.fdFlags		= null;	// finder flags
	promisedFile.promisedFlavor = kResourceTransferType;
	
	// add phfs and TEXT flavours
	AddDragItemFlavor( drag, *itemRef, flavorTypePromiseHFS, &promisedFile, sizeof(PromiseHFSFlavor), flags );
	return true;
	
/*	OSErr error = noErr;
	DragReference theDragRef;
	ItemReference theItemRef = 1;
	
	// create the drag reference
	NewDrag( &theDragRef );
	if( MemError() ) return;
	SetDragSendProc( theDragRef, sendProc, this );
	
	RgnHandle		dragRgn = NewRgn(),
					subtractRgn = NewRgn();
	
	// get region of dragged items, using translucent dragging where possible
	Point		dragOffset;
	GWorldPtr	imageGWorld = nil;
	
	resData = GetResourceData( ownerWindow );
	while( resData )
	{
		if( r.selected )
			UnionRgn( r.nameIconRgn, dragRgn, dragRgn );	// add new region to rest of drag region
		resData = r.next;
	}
	
	if( g.translucentDrag )
	{
		short resCounter = 0;
		SetPt( &dragOffset, 0, kFileHeaderHeight );
		resData = GetResourceData( ownerWindow );
		
		while( !r.selected )
		{
			resCounter++;
			resData = r.next;
		}
		
		error = CreateDragImage( resData, &imageGWorld );
		if( !error )
		{
			// init mask region
			RgnHandle maskRgn = NewRgn();
			CopyRgn( r.nameIconRgn, maskRgn );
			OffsetRgn( maskRgn, 0, -kFileLineHeight * resCounter );
			
			// init rects
			Rect sourceRect, destRect;
			SetRect( &sourceRect, 0, 0, g.nameColumnWidth, kFileLineHeight );
			SetRect( &destRect, 0, 0, g.nameColumnWidth, kFileLineHeight );
			OffsetRect( &destRect, 0, kFileHeaderHeight );
			
			// init GWorld
			PixMapHandle imagePixMap = GetGWorldPixMap( imageGWorld );
			DragImageFlags imageFlags = kDragStandardTranslucency | kDragRegionAndImage;
			error = SetDragImage( theDragRef, imagePixMap, maskRgn, dragOffset, imageFlags );
			CopyBits( &GrafPtr( imageGWorld )->portBits, &GrafPtr( ownerWindow )->portBits, &sourceRect, &destRect, srcCopy, maskRgn );
			if( error ) SysBeep(0);
			DisposeGWorld( imageGWorld );
			DisposeRgn( maskRgn );
		}
	}
	
	// subtract middles from icons
	MakeGlobal( ownerWindow, NewPoint(), &globalMouse );
	CopyRgn( dragRgn, subtractRgn );						// duplicate region
	InsetRgn( subtractRgn, 2, 2 );							// inset it by 2 pixels
	DiffRgn( dragRgn, subtractRgn, dragRgn );				// subtract subRgn from addRgn, save in nameIconRgn
	OffsetRgn( dragRgn, globalMouse.h, globalMouse.v );		// change drag region to global coords
	
	// add flavour data to drag
	error = AddDragItemFlavor( theDragRef, theItemRef, flavorTypePromiseHFS, &theFile, sizeof(PromiseHFSFlavor), theFlags );
	error = AddDragItemFlavor( theDragRef, theItemRef, kResType, nil, 0, theFlags );
	
	// track the drag, then clean up
	error = TrackDrag( theDragRef, theEvent, dragRgn );
	if( theDragRef )	DisposeDrag( theDragRef );
	if( subtractRgn )	DisposeRgn( subtractRgn );
	if( dragRgn )		DisposeRgn( dragRgn );
	return error == noErr;	*/
}

/*** ACCEPT DRAG ***/
pascal Boolean DataBrowserAcceptDrag( ControlRef browser, DragRef drag, DataBrowserItemID item )
{
	#pragma unused( browser, drag, item )
/*	OSStatus error = noErr;
	Size size = null;
	DragItemRef dragItem = 1;
	UInt16 index, totalItems;
	
	CountDragItems( theDrag, &totalItems );
	for( index = 1; index <= totalItems; index++ )
	{
		GetDragItemReferenceNumber( theDrag, index, &dragItem );
		error = GetFlavourDataSize( theDrag, dragItem, kDragFlavourTypeResource, &size );
//		if( error )	return false;
		if( !error ) index = totalItems;	// stop when valid item is reached
	}
	return size >= sizeof(ResTransferDesc);
*/	return true;
}

/*** RECEIVE DRAG ***/
pascal Boolean DataBrowserReceiveDrag( ControlRef browser, DragRef drag, DataBrowserItemID item )
{
	#pragma unused( browser, drag, item )
	return true;
}

/*** POSTÐPROCESS DRAG ***/
pascal void DataBrowserPostProcessDrag( ControlRef browser, DragRef drag, OSStatus trackDragResult )
{
	#pragma unused( browser, drag, trackDragResult )
}

/*** SEND PROMISED FILE ***/
pascal OSErr SendPromisedFile( FlavorType type, void *dragSendRefCon, ItemReference item, DragReference drag )
{
	OSErr			error = noErr;
	ControlRef		browser = (ControlRef) dragSendRefCon;
	FSSpec			fileSpec;
	Str255			fileName;
	short			vRefNum;
	long			dirID;
	
	if( type != flavorTypePromiseHFS ) return badDragFlavorErr;
		
	// create file
	GetIndString( fileName, kFileNameStrings, kStringNewDragFileName );
	FindFolder( kOnSystemDisk, /*kTemporaryFolderType*/kDesktopFolderType, kCreateFolder, &vRefNum, &dirID );
	FSMakeFSSpec( vRefNum, dirID, fileName, &fileSpec );
	FSpCreateResFile( &fileSpec, kResKnifeCreator, kResourceFileType, smSystemScript );
	
	// save resources into file
	DragData clientData;				// waiting for jim to add a ControlRef to DataBrowserItemUPP;	bug: jim no longer works at Apple
	clientData.browser = browser;
	clientData.fileSpec = &fileSpec;
	DataBrowserItemUPP callback = NewDataBrowserItemUPP( AddResourceToDragFile );
					/*		control,	container,		recurse,		state,				callback, clientData	*/
	ForEachDataBrowserItem( browser, kDataBrowserNoItem, true, kDataBrowserItemIsSelected, callback, &clientData );
	
	// save resources in file
/*	ResourceObjectPtr resource = GetResourceData( file->window );
	short refNum = FSpOpenResFile( &fileSpec, fsRdWrPerm );
	UseResFile( refNum );
	while( resData )
	{
		if( resource->Selected() )
			AddResource( resource->Data(), resource->Type(), resource->ID(), resource->Name() );
		resData = resource->Next();
	}
	CloseResFile( refNum );
	UseResFile( g.appResFile );
*/	
	error = SetDragItemFlavorData( drag, item, type, &fileSpec, sizeof(FSSpec), 0 );
	return error;
}

/*** ADD RESOURCE TO DRAG FILE ***/
pascal void AddResourceToDragFile( DataBrowserItemID item, DataBrowserItemState state, void *clientData )
{
	#pragma unused( state )
//	FSSpecPtr fileSpec	= (FSSpecPtr) clientData;
	WindowRef window	= GetControlOwner( ((DragDataPtr) clientData)->browser );
	FileWindowPtr file	= (FileWindowPtr) GetWindowRefCon( window );
	ResourceObjectPtr resource = file->GetResource( item );
	
	// add resource to file
	short oldFile		= CurResFile();
	short refNum		= FSpOpenResFile( ((DragDataPtr) clientData)->fileSpec, fsRdWrPerm );
	UseResFile( refNum );
	AddResource( resource->Data(), resource->Type(), resource->ID(), resource->Name() );
	if( ResError() == addResFailed )
	{
		DisplayError( "\pDrag Partially Failed", "\pCould not add a resource to file." );
	}
	else
	{
		SetResAttrs( resource->Data(), resource->Attributes() );
		ChangedResource( resource->Data() );
		
		// clean up & move on
		DetachResource( resource->Data() );
	}
	CloseResFile( refNum );
	UseResFile( oldFile );
}

#else

  /*********************/
 /* FAKE DATA BROWSER */
/*********************/

/*** CLEAR SELECTION ***/
OSStatus FileWindow::ClearSelection( void )
{
	ResourceObjectPtr resource = resourceMap;
	while( resource )
	{
		resource->Select( false );
		resource = resource->Next();
	}
	return noErr;
}

#endif