#ifndef _ResKnife_Transfer_
#define _ResKnife_Transfer_

/*!
	@header			Transfer
	@discussion		Declares the structure used for intra- and inter-application data transfer. All modern resource editors support this structure, and ResKnife handles both copy & paste and drag & drop transfer methods.
*/

/*!
	@class			ResTransferDesc
	@discussion		Useful for interaplication data transfer.
*/
typedef class
{
/*!	@var version	Should be kResTransferDescCurrentVersion. */
	UInt16			version;
/*!	@var resType	Type of resource being copied/dragged. */
	ResType			resType;
/*!	@var resID		ID of resource being copied/dragged. */
	SInt16			resID;
/*!	@var resFlags	Flags (attributes) of this resource. */
	UInt16			resFlags;
/*!	@var resName	Name of this resource. */
	Str255			resName;
/*!	@var hostApp	Creator of application that this copy/drag started from. */
	OSType			hostApp;
/*!	@var hostData	Data for private use by host. */
	UInt32			hostData[4];
/*!	@var dataSize	Size of resource data. */
	UInt32			dataSize;
/*!	@var data		Variably-sized array with resource data. */
	UInt8			data[kVariableLengthArray];		// bug: zero-length resources do weird shit
}	ResTransferDesc, *ResTransferPtr;

#endif