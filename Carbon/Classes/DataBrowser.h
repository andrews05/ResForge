#include "ResKnife.h"
#include "FileWindow.h"

#ifndef _ResKnife_DataBrowser_
#define _ResKnife_DataBrowser_

/*!
 *	@header			DataBrowser
 *	@discussion		Handles the databrowser control on post-CarbonLib systems, and mimics it on pre-CarbonLib machines.
 */

typedef struct
{
	ControlRef	browser;
	FSSpecPtr	fileSpec;
}	DragData,	*DragDataPtr;

/*!
 *	@enum					DataBrowser Column IDs
 *	@discussion				The data browser requires IDs for identifiying columns when adding data. These constants provide those IDs.
 *	@constant kDBNameColumn	The name column, also include resource icon and disclosure triangle.
 *	@constant kDBTypeColumn	The type column contains the four-byte resType of each resource.
 *	@constant kDBIDColumn	The ID column contains 16-bit signed resource IDs
 *	@constant kDBSizeColumn	The size column reports the size of each resource's data in bytes or multiples thereof.
 */
enum
{
	kDBNameColumn	= FOUR_CHAR_CODE('name'),
	kDBTypeColumn	= FOUR_CHAR_CODE('type'),
	kDBIDColumn		= FOUR_CHAR_CODE('id  '),
	kDBSizeColumn	= FOUR_CHAR_CODE('size')
};

const DataBrowserItemID kDataBrowserDataForkItem = 0xFFFFFFFE;	// bug in data browser preventts use of 0xFFFFFFFF

/*!
 *	@function		AddDataBrowserColumn
 *	@discussion		Adds columns to the data browser one at a time.
 */
void AddDataBrowserColumn( ControlRef browser, DataBrowserPropertyID column, UInt16 position );
/*!
 *	@function		DataBrowserItemData
 *	@discussion		DataBrowser callback.
 */
pascal OSStatus DataBrowserItemData( ControlRef browser, DataBrowserItemID itemID, DataBrowserPropertyID property, DataBrowserItemDataRef itemData, Boolean changeValue );
/*!
 *	@function		SortDataBrowser
 *	@discussion		DataBrowser callback.
 */
pascal Boolean SortDataBrowser( ControlRef browser, DataBrowserItemID itemOne, DataBrowserItemID itemTwo, DataBrowserPropertyID sortProperty );
/*!
 *	@function		DataBrowserMessage
 *	@discussion		DataBrowser callback.
 */
pascal void DataBrowserMessage( ControlRef browser, DataBrowserItemID itemID, DataBrowserItemNotification message, DataBrowserItemDataRef itemData );
/*!
 *	@function		DataBrowserAddDragItem
 *	@discussion		DataBrowser callback.
 */
pascal Boolean DataBrowserAddDragItem( ControlRef browser, DragRef drag, DataBrowserItemID item, DragItemRef *itemRef );
/*!
 *	@function		DataBrowserAcceptDrag
 *	@discussion		DataBrowser callback.
 */
pascal Boolean DataBrowserAcceptDrag( ControlRef browser, DragRef drag, DataBrowserItemID item );
/*!
 *	@function		DataBrowserReceiveDrag
 *	@discussion		DataBrowser callback.
 */
pascal Boolean DataBrowserReceiveDrag( ControlRef browser, DragRef drag, DataBrowserItemID item );
/*!
 *	@function		DataBrowserPostProcessDrag
 *	@discussion		DataBrowser callback.
 */
pascal void DataBrowserPostProcessDrag( ControlRef browser, DragRef drag, OSStatus trackDragResult );
/*!
 *	@function		SendPromisedFile
 *	@discussion		Creates the promised file and sends the FSSpec for it back.
 */
pascal OSErr SendPromisedFile( FlavorType theType, void *dragSendRefCon, ItemReference item, DragReference drag );
/*!
 *	@function		AddResourceToDragFile
 *	@discussion		Adds each resource to the file created by SendPromisedFile. Called once per resource.
 */
pascal void AddResourceToDragFile( DataBrowserItemID item, DataBrowserItemState state, void *clientData );

#endif