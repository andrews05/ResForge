#include "Asynchronous.h"

//=======================================================================================
// Statics
//=======================================================================================
static Boolean			gsSHInited = false;			// Flags whether Helper has been inited
static Boolean			*gsSHNeedsTime;				// Pointer to app "SH needs time" flag

static SHOutputVars		gsSHOutVars;				// Sound output variables
static SHInputVars		gsSHInVars;					// Sound input variables

static SndCallBackUPP	gsSHPlayCompletionUPP;		// UPP for SoundCallBackProc 	(BDM)
static SICompletionUPP	gsSHRecordCompletionUPP;	// UPP for SIRecordCompletion	(BDM)

//=======================================================================================
// Static prototypes
//=======================================================================================
static long SHNewRefNum( void );
static OSErr SHNewOutRec( SHOutPtr *outRec );
static pascal void SHPlayCompletion( SndChannelPtr channel, SndCommand *command );
static pascal void SHRecordCompletion( SPBPtr inParams );
static OSErr SHInitOutRec( SHOutPtr outRec, long refNum, Handle sound, char handleState );
static void SHReleaseOutRec( SHOutPtr outRec );
static OSErr SHQueueCallback( SndChannel *channel );
static OSErr SHBeginPlayback( SHOutPtr outRec );
static char SHGetState( Handle snd );
static SHOutPtr SHOutRecFromRefNum( long refNum );
static void SHPlayStopByRec( SHOutPtr outRec );
static OSErr SHGetDeviceSettings( long inRefNum, short *numChannels, Fixed *sampleRate, short *sampleSize, OSType *compType );

//=======================================================================================
//
//	pascal OSErr SHInitSoundHelper( Boolean *attnFlag, short numChannels )
//
//	Summary:
//		This routine initializes the Asynchronous Sound Helper.
//
//	Scope:
//		Public.
//
//	Parameters:
//		attnFlag		Pointer to an application Boolean.  This Boolean will be set to
//						true when the Helper needs a call to SHIdle.  For example, the
//						application will have a global Boolean with a name like
//						"gCallHelper", and will pass the address of that global to
//						SHInitSoundHelper.  Then, in the application's main event loop,
//						will simply check gCallHelper, and call SHIdle if it is set.
//		numChannels		Tells the Helper how many output records to allocate. The number
//						of simultaneous sounds that can be produced by the Helper is
//						limited by a) the number of simultaneous channels the Sound
//						Manager allows, and b) the number of output records specified by
//						this parameter. If you specify zero, a reasonable default (4) is
//						used.
//
//	Returns:
//		MemError()		If there is one.
//		memFullErr		If the output array was nil but MemError returned noErr.
//		noErr			Otherwise.
//
//	Operation:
//		This routine simply allocates the output records, initializes some statics, and
//		sets a flag that tells whether the Helper has been initialized.
//
//=======================================================================================
pascal OSErr SHInitSoundHelper( Boolean *attnFlag, short numChannels )
{
	OSErr error = noErr;
	
	// Use default number of channels if zero was specified
	if( numChannels == 0 )
		numChannels = kSHDefChannels;
	
	// Remember the address of the application's "attention" flag
	gsSHNeedsTime = attnFlag;
	
	// Allocate the channels
	gsSHOutVars.numOutRecs = numChannels;
	gsSHOutVars.outArray = (SHOutPtr) NewPtrClear( numChannels * sizeof(SHOutRec) );

	// Set up UPPs for play completion and input completion
	gsSHPlayCompletionUPP 	= NewSndCallBackUPP( SHPlayCompletion );
	gsSHRecordCompletionUPP = NewSICompletionUPP( SHRecordCompletion );
	
	// If successful, flag that we're initialized and exit
	if( gsSHOutVars.outArray != nil )
	{
		gsSHInited = true;
		return error;
	}
	else
	{
		// Return some kind of error (MemError if there is one, otherwise make one up )
		error = MemError();
		if( error == noErr )
			error = memFullErr;
		return error;
	}
}

//=======================================================================================
//
//	pascal void SHIdle( void )
//
//	Summary:
//		This routine performs various cleanup operations when sounds have finished
//		playing or recording.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		Nothing.
//
//	Operation:
//		First, SHIdle clears the flag that indicates an SHIdle call is needed.  Next,
//		SHIdle performs playback cleanup.  It iterates through the output records
//		looking for records that are both in use and complete.  Such records are disposed
//		with SHReleaseOutRec.  This frees the record for use later, and closes the sound
//		channel with the Sound Manager.  Next, SHIdle performs recording cleanup.  It
//		checks if recording is underway and is flagged as complete.  If so, it unlocks
//		the (previously locked) input handle, and checks for errors.  If errors occurred,
//		the input handle is disposed and the recordErr field of the input variable record
//		is filled with the error.  This allows the error to later be reported to the
//		caller when he calls SHGetRecordedSound.  If no error occured, then the sound
//		header is re-written into the input sound handle, this time with the correct
//		length, and the handle is sized down to match the actual number of samples that
//		were recorded.  Then the sound input device is closed and the application is
//		notified that recording is complete through his Boolean completion flag.
//
//=======================================================================================
pascal void SHIdle( void )
{
	OSErr error = noErr;
	long	realSize;
	
	// Immediately turn off the application's "Helper needs time" flag
	*gsSHNeedsTime = false;

	// Do playback cleanup
	for( short i = 0; i < gsSHOutVars.numOutRecs; i++ )
		if( gsSHOutVars.outArray[i].inUse &&
				gsSHOutVars.outArray[i].channel.userInfo == kSHComplete )
			// We've found a channel that needs closing...
			SHReleaseOutRec( &gsSHOutVars.outArray[i] );
	
	// Do recording cleaunp
	if( gsSHInVars.recording && gsSHInVars.recordComplete )
	{
		HUnlock( gsSHInVars.inHandle );
		
		if( gsSHInVars.inPB.error && gsSHInVars.inPB.error != abortErr )
		{
			// An error (other than a manual stop) occurred during recording.  Kill the
			// handle and save the error code.
			gsSHInVars.recordErr = gsSHInVars.inPB.error;
			DisposeHandle( gsSHInVars.inHandle );
			gsSHInVars.inHandle = nil;
		}
		else
		{
			// Recording completed normally (which includes abortErr, the "error" that
			// occurs when recording is manually stopped).  We re-write the header (to
			// slam the correct size in there), and size the handle to fit the actual
			// recorded size (which either shortens the handle, or doesn't change its
			// size -- that's why we don't bother checking the error).
			gsSHInVars.recordErr = noErr;
			realSize = gsSHInVars.inPB.count + gsSHInVars.headerLength;
			error = SetupSndHeader( (SndListHandle) gsSHInVars.inHandle, gsSHInVars.numChannels,
				gsSHInVars.sampleRate, gsSHInVars.sampleSize, gsSHInVars.compType,
				kSHBaseNote, realSize, &gsSHInVars.headerLength );
			SetHandleSize( gsSHInVars.inHandle, realSize );		// Shorten the handle
		}
		
		// Error or not, close the recording device, and notify the application that
		// recording is complete, through the recording-completed flag that the caller
		// originally passed into SHRecordStart.
		SPBCloseDevice( gsSHInVars.inRefNum );
		gsSHInVars.recording = false;
		gsSHInVars.inRefNum = 0;
		if( gsSHInVars.appComplete != nil )
			*gsSHInVars.appComplete = true;
	}
}

//=======================================================================================
//
//	pascal void SHKillSoundHelper( void )
//
//	Summary:
//		This routine terminates the Asynchronous Sound Helper.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		Nothing.
//
//	Operation:
//		This routine, after checking that the Helper was previously initialized, stops
//		all current playback and recording, waits 1/60th of a second (to allow the Sound
//		Manager to call our callback routines, SHPlayCompletion and SHRecordCompletion),
//		then calls SHIdle to force cleanup (releasing sound channels and closing the
//		sound input device if appropriate).  Then, SHKillSoundHelper disposes of the
//		output records.
//
//=======================================================================================
pascal void SHKillSoundHelper( void )
{
	unsigned long	timeout;
	Boolean	outputClean, inputClean;
	
	if( !gsSHInited )
		return;

	SHPlayStopAll();	// Kill all playback
	SHRecordStop();		// Kill recording
	
	// Now sync-wait for everything to clean itself up
	timeout = TickCount() + kSHSyncWaitTimeout;
	do {
		if( *gsSHNeedsTime )
			SHIdle();			// Clean up when required

		// Check if all our output channels are cleaned up
		outputClean = true;
		for( short i = 0; i < gsSHOutVars.numOutRecs && outputClean; i++ )
			if( gsSHOutVars.outArray[i].inUse )
				outputClean = false;
		
		// Check whether our recording is cleaned up
		inputClean = !gsSHInVars.recording;
		
		if( inputClean && outputClean )
			break;
	} while (TickCount() < timeout );
	
	// Lose our preallocated sound channels
	DisposePtr( (Ptr) gsSHOutVars.outArray );
}

//=======================================================================================
//
//	long SHNewRefNum( void )
//
//	Summary:
//		This routine returns the next available output reference number.
//
//	Scope:
//		Private.
//
//	Parameters:
//		None.
//
//	Returns:
//		The next available output reference number.
//
//	Operation:
//		The output variable nextRef contains the next available reference number.  This
//		function returns the value of nextRef then increments it.  This way, output ref-
//		erence numbers are unique throughout a session (modulo 2,147,483,647).
//
//=======================================================================================
long SHNewRefNum( void )
{
	return gsSHOutVars.nextRef++;
}

//=======================================================================================
//
//	OSErr SHNewOutRec( SHOutPtr *outRec )
//
//	Summary:
//		This routine attempts to return the first available output record.
//
//	Scope:
//		Private.
//
//	Parameters:
//		outRec		A pointer to an SHOutRecPtr.  This is where SHNewOutRec puts
//					the pointer to the output record.
//
//	Returns:
//		kSHErrOutaChannels		If no free output record was found.
//		noErr					Otherwise.
//
//	Operation:
//		SHNewOutRec simply iterates through the output record array looking for a record
//		that is not in use.  If all the records are in use, SHNewOutRec returns the
//		Helper error code kSHErrOutaChannels.  If a record is found, then the address of
//		the record is stored via the VAR parameter, and noErr is returned.
//
//=======================================================================================
OSErr SHNewOutRec( SHOutPtr *outRec )
{
	// First look for a free channel among our preallocated output records
	for( short i = 0; i < gsSHOutVars.numOutRecs; i++ )
		if( !gsSHOutVars.outArray[i].inUse )
		{
			*outRec = &gsSHOutVars.outArray[i];
			return noErr;
		}
	
	return kSHErrOutaChannels;
}

//=======================================================================================
//
//	pascal void SHPlayCompletion( SndChannelPtr channel, SndCommand *command )
//
//	Summary:
//		This routine is the playback callback routine we provide to the Sound Manager.
//
//	Scope:
//		Private.
//
//	Parameters:
//		channel		A pointer to the sound channel that is calling back.  It is calling
//					back because we queued up a callbackCmd.
//		command		A pointer to the actual command that caused us to be called back.
//					This command happens to have important information (like the app's
//					A5, and a constant we can use to verify that this is a "real" call-
//					back, as opposed to one that has been erroroneously generated by the
//					Sound Manager).
//
//	Returns:
//		Nothing.
//
//	Operation:
//		This routine first looks for our "completion signature."  This is how we know
//		that the callback really means the sound has completed.  There is a bug in the
//		Sound Manager that may cause callbacks that weren't specifically requested, and
//		this constant allows us to distinguish our "real" callback from one that is a
//		result of that bug.  If the callback is hip, then we set up A5 (so we can ref-
//		erence our globals), and set the application's attention flag.  Also, we set
//		the channel's userInfo field to a constant that SHIdle will recognize, so SHIdle
//		will know the sound on that channel has completed, and that the channel can be
//		freed.
//
//=======================================================================================
pascal void SHPlayCompletion( SndChannelPtr channel, SndCommand *command )
{
	// Look for our "callback signature" in the sound command.
	if( command->param1 == kSHCompleteSig )
	{	
		channel->userInfo = kSHComplete;
		*gsSHNeedsTime = true;				// Tell the app to give us an SHIdle call
	}
}

//=======================================================================================
//
//	pascal void SHRecordCompletion( SPBPtr inParams )
//
//	Summary:
//		This routine is the recording callback routine we provide to the Sound Manager.
//
//	Scope:
//		Private.
//
//	Parameters:
//		inParams		This points to the input sound parameter block that has completed
//						recording.
//
//	Returns:
//		Nothing.
//
//	Operation:
//		When recording completes for any reason (error, consumed all the memory that was
//		provided, abort, etc.) then the Sound Manager calls our callback routine.  This
//		routine first grabs A5 from the SPB's userLong field and sets us up to use our
//		globals.  Then, it sets the application's "Helper needs time" Boolean, and sets
//		our internal flag that recording has completed (so SHIdle will know to close the
//		recording device, etc. )
//
//=======================================================================================
pascal void SHRecordCompletion( SPBPtr inParams )
{
	#pragma unused( inParams )
	*gsSHNeedsTime = true;						// Notify the app to give us time
	gsSHInVars.recordComplete = true;			// Make a note to ourselves, too
}

//=======================================================================================
//
//	OSErr SHInitOutRec( SHOutPtr outRec, long refNum, Handle sound, char handleState )
//
//	Summary:
//		This routine is used to fill out an SHOutRec and call SndNewChannel.
//
//	Scope:
//		Private.
//
//	Parameters:
//		outRec			A pointer to the SHOutRec we're filling out.
//		refNum			The output reference number we'll give back to the caller.
//		sound			A locked, non-purgeable handle to a (hopefully) valid sound.
//		handleState		The original handle state, before the HLock and HNoPurge.  This
//						allows SHReleaseOutRec to properly reset the handle's flags when
//						playback is complete.
//
//	Returns:
//		OSErr			Error results of SndNewChannel call, if an error occurred.
//		noErr			Otherwise.
//
//	Operation:
//		This routine is called to fill out a SHOutRec.  First, it clears the SndChannel
//		within the SHOutRec to all zeros.  It then installs the default queue size, and
//		calls the Sound Manager routine SndNewChannel.  If an error occurs, we return
//		it right away.  If not, then we fill out the rest of the fields in the SHOutRec.
//		Note that in the call to SndNewChannel, we specify NO SYNTHESIZER, and NO INIT-
//		IALIZATION.  This is because the Helper is a "sound service," and has no freakin'
//		idea what kind of sound the caller is going to try to play using this channel.
//		So, we assume nothing.  Also note that we provide our completion routine,
//		SHPlayCompletion, to SndNewChannel.
//
//=======================================================================================
OSErr SHInitOutRec( SHOutPtr outRec, long refNum, Handle sound, char handleState )
{
	OSErr			error;
	SndChannelPtr	channel;
	
	// Initialize the sound channel inside outRec.  We'll clear the bytes to zero,
	// install the proper queue size, then call SndNewChannel.
	for( unsigned short i = 0; i < sizeof(SndChannel); i++ )
		((char *) &outRec->channel)[i] = 0;
	outRec->channel.qLength = stdQLength;
	channel = &outRec->channel;
	error = SndNewChannel( &channel, kSHNoSynth, kSHNoInit, gsSHPlayCompletionUPP );
	if( error != noErr )
		return error;
	
	// Initialize the rest of the record and return noErr.  Note that we only set the
	// record's inUse flag if the SndNewChannel call was successful.
	outRec->refNum = refNum;
	outRec->sound = sound;
	outRec->rate = 0;
	outRec->handleState = handleState;
	outRec->inUse = true;
	outRec->paused = false;
	return error;
}

//=======================================================================================
//
//	void SHReleaseOutRec( SHOutPtr outRec )
//
//	Summary:
//		This routine "releases," or frees up an output record.
//
//	Scope:
//		Private.
//
//	Parameters:
//		outRec		A pointer to the output record we want to release.
//
//	Returns:
//		Nothing.
//
//	Operation:
//		If the output record's inUse flag is set, that means that SndNewChannel has been
//		called for it.  In that case, we call SndDisposeChannel to allow the Sound Man-
//		ager to dispose it's internal data structures for this channel.  Either way, if
//		there's an associated sound, we check whether the sound is playing on any other
//		channel, and if not, we reset it's handle flags.  Finally, we clear the record's
//		inUse flag, thereby allowing it to be reused.
//
//=======================================================================================
void SHReleaseOutRec( SHOutPtr outRec )
{
	Boolean found = false;
	
	// An SHOutRec's inUse flag only gets set if SndNewChannel has been called on the
	// record's sound channel.  So if it is in use, we try a call to SndDisposeChannel,
	// and ignore the error (what else can we do? )
	if( outRec->inUse )
		SndDisposeChannel( &outRec->channel, kSHQuietNow );

	// If this sound handle isn't being used by some other output record, kindly restore
	// the original handle state.
	if( outRec->sound != nil )
	{
		for( short i = 0; i < gsSHOutVars.numOutRecs && !found; i++ )
			if( &gsSHOutVars.outArray[i] != outRec && gsSHOutVars.outArray[i].inUse &&
					gsSHOutVars.outArray[i].sound == outRec->sound )
				found = true;
		
		if( !found )
			HSetState( outRec->sound,outRec->handleState );
	}
	
	outRec->inUse = false;
}

//=======================================================================================
//
//	OSErr SHQueueCallback( SndChannel *channel )
//
//	Summary:
//		This routine queues up a verifyable callback in the given sound channel.
//
//	Scope:
//		Private:
//
//	Parameters:
//		channel		The sound channel we want a callback from.
//
//	Returns:
//		OSErr		Results of the SndDoCommand call.
//
//	Operation:
//		This routine queues up a sound command in the given channel that will cause a
//		callback.  This is how we'll know the sound completed.  In order to make the
//		callback verifyable, we stuff kSHCompleteSig into param1.  We can test for this
//		value within the callback routine.  Also, since the poor callback is called at
//		interrorupt time and can't count on its A5 world, we provide the application A5
//		in param2.
//
//=======================================================================================
OSErr SHQueueCallback( SndChannel *channel )
{
	SndCommand	command;

	command.cmd = callBackCmd;
	command.param1 = kSHCompleteSig;		// To make the callback verifyable.
	command.param2 = 0L;

	return SndDoCommand( channel, &command, kSHWait );
}

//=======================================================================================
//
//	OSErr SHBeginPlayback(SHOutPtr outRec )
//
//	Summary:
//		This routine begins playback of the sound that's installed in the given SHOutRec.
//
//	Scope:
//		Private.
//
//	Parameters:
//		outRec		The output record that we want to start playback on.
//
//	Returns:
//		OSErr		Error results of SndPlay, if an error occurred.
//		noErr		Otherwise.
//
//	Operation:
//		This routine calls SndPlay (asynchronously) for the sound that is installed in
//		the given output record.  This begins playback.  Immediately following that, we
//		queue up a callback, so that when the sound that we just start completes, we'll
//		get a callback (to SHPlayCompletion), and we'll know that the channel needs to
//		be released.
//
//	IMPORTANT:
//		This routine is called from SHPlayByID, and SHPlayByHandle when a sound handle is
//		provided.  The purpose of these routines is to trigger a sound, and if you call
//		SHPlayByID or SHPlayByHandle that way, DON'T use SHGetChannel to get the sound
//		channel Helper is using to play the sound, then subsequently call SndPlay your-
//		self to play some other sound.  Why not?  There is a bug in pre-7.0 Systems that
//		causes a crash if more than one SndPlay call is made on the same channel.  Helper
//		will never do this on its own, and you shouldn't either. If you want a sound
//		channel that you want to send commands to, call SHPlayByHandle with a nil handle,
//		then call SHGetChannel to retreive a pointer to the channel.
//
//=======================================================================================
OSErr SHBeginPlayback( SHOutPtr outRec )
{
	OSErr error = noErr;
	
	// First, initiate playback.  If an error occurs, return it immediately.
	error = SndPlay( &outRec->channel, (SndListHandle)outRec->sound, kSHAsync );
	if( error != noErr )
		return error;
	
	// Playback started okay.  Let's queue up a callback command so we'll know when
	// the sound is finished.
	SHQueueCallback( &outRec->channel );		// ignore error (what can we do? )
	return error;
}

//=======================================================================================
//
//	char SHGetState( Handle snd )
//
//	Summary:
//		This routine is a local replacement for HGetState which tries to find snd in an
//		existing output record.
//
//	Scope:
//		Private:
//
//	Parameters:
//		snd			The handle we want the handle state for
//
//	Returns:
//		A char representing the handle flags (either currently or from some existing
//		output record).
//
//	Operation:
//		This routine searches the output record array for an output record that is both
//		in use AND has a "sound" field equal to the parameter snd.  What this means is
//		that we've found an output record that is currently playing snd.  If we find
//		such a record, we return the "handleState" field of that output record.  If no
//		such record is found, then we return the results of HGetState(snd).  The reason
//		we need this is that you could re-trigger a sound (that is, play the same sound
//		simultaneously on more than one Helper output channel).  In such a case, the
//		first SHPlayByID or (ByHandle) call would get the actual handle state (from
//		HGetState).  If another SHPlayByID call came in while the original was still
//		playing, the handleState from the existing output record would be retured.  This
//		way, the second Play doesn't save a "locked" state and restore to a locked state
//		when the sound has completed.
//
//=======================================================================================
char SHGetState( Handle snd )
{
	// Look for an output record that has snd for a sound.  If one is found, grab and
	// return its handleState instead of the handle's current flags.
	for( short i = 0; i < gsSHOutVars.numOutRecs; i++ )
		if( gsSHOutVars.outArray[i].inUse && gsSHOutVars.outArray[i].sound == snd )
			return gsSHOutVars.outArray[i].handleState;
	
	return HGetState(snd);
}

//=======================================================================================
//
//	pascal OSErr SHPlayByID( short resID, long *refNum )
//
//	Summary:
//		This routine begins asynchronous playback of the 'snd ' resource with ID resID.
//
//	Scope:
//		Public.
//
//	Parameters:
//		resID		The resource ID of the 'snd ' resource the caller wants to play back.
//		refNum		A pointer to where to store the output reference number.  THIS IS
//					OPTIONAL.  If nil is specified, the refNum is not returned.
//
//	Returns:
//		ResError()				If the GetResource failed, and ResError gave an error.
//		resNotFound				If the GetResource failed, but ResError was noErr.
//		kSHErrOutaChannels		If the SHNewOutRec call failed.
//		OSErr					If the SHInitOutRec call failed.
//		OSErr					If the SHBeginPlayback call failed.
//		noErr					Otherwise.
//
//	Operation:
//		This routine plays the 'snd ' resource referrored to by ID resID.  First, we try
//		to load the sound resource.  If successful, we note the handle state of the
//		sound handle, and set it to be nonpurgeable (because we don't want subsequent
//		operations, namely the SndNewChannel call that happens in SHInitOutRec, to wipe
//		out the sound we so carefully read into memory).  Then we get a reference number
//		and a pointer to the next free output record.  If successful, we initialize the
//		output record (and open the sound channel) with SHInitOutRec.  If successful,
//		we move the sound handle as high in the heap as we can (to help avoid fragmen-
//		tation), and lock it.  Then we call SHBeginPlayback to start the sound playing
//		and queue up a callback so we'll know when it's done.  If successful, we return
//		the reference number (if the caller wants it).
//
//	IMPORTANT:
//		DO NOT start a sound playing with SHPlayByID, get it's channel with SHGetChannel,
//		and then do another SndPlay on that channel!  This will crash on pre-7.0 systems.
//		If you want a channel, use SHPlayByHandle with a nil handle.  See the comments
//		for SHPlayByHandle and SHBeginPlayback.
//		
//=======================================================================================
pascal OSErr SHPlayByID( short resID, long *refNum )
{
	Handle		sound;
	char		oldhandleState;
	short		ref;
	OSErr		error;
	SHOutPtr	outRec;
	
	// First, try to get the caller's 'snd ' resource.  If we can't return ResError().
	// If we DO get the sound, save it's flags, then set it to be nonpurgeable.  This
	// is because some of the Sound Manager stuff below may cause memory allocation,
	// which could cause the sound to be purged.  We don't want that, since we're
	// going to start playing it real soon.
	sound = GetResource( soundListRsrc, resID );
	if( sound == nil )
	{
		error = ResError();
		if( error == noErr )
			error = resNotFound;
		return error;
	}
	oldhandleState = SHGetState(sound );
	HNoPurge(sound );
		
	// Now let's get a reference number and an output record.
	ref = SHNewRefNum();
	error = SHNewOutRec( &outRec );
	if( error != noErr )
	{
		HSetState( sound, oldhandleState );
		return error;
	}
	
	// Now let's fill in the output record with all the pertinent information.  This
	// routine also initializes the sound channel and flags outRec as "in use."
	error = SHInitOutRec(outRec, ref, sound, oldhandleState );
	if( error != noErr )
	{
		HSetState( sound, oldhandleState );
		SHReleaseOutRec( outRec );
		return error;
	}
	
	// At this point, we're in pretty good shape.  We've got a reference number, an
	// initialized output record, and the sound handle.  Let's party.
	MoveHHi( sound );
	HLock( sound );
	error = SHBeginPlayback( outRec );
	if( error != noErr )
	{
		HSetState( sound, oldhandleState );
		SHReleaseOutRec( outRec );
		return error;
	}
	else
	{
		if( refNum != nil  )			// refNum is optional -- the caller may not want it
			*refNum = ref;
		return error;
	}
}

//=======================================================================================
//
//	pascal OSErr SHPlayByHandle( Handle sound, long *refNum )
//
//	Summary:
//		This routine begins asynchronous playback of a sound provided in a handle.
//
//	Scope:
//		Public.
//
//	Parameters:
//		sound		A handle to the sound the caller wants to play.  This may optionally
//					be nil, indicating that the sound channel should be opened, but no
//					SndPlay call should be made.  If a caller does this, he usually calls
//					SHGetChannel to get a pointer to the sound channel, so he can send
//					sound commands to the channel.
//		refNum		A pointer to where to store the output reference number.  THIS IS
//					OPTIONAL.  If nil is passed, the reference number is not returned.
//
//	Returns:
//		kSHErrOutaChannels		If the SHNewOutRec call failed.
//		OSErr					If the SHInitOutRec call failed.
//		OSErr					If the SHBeginPlayback call failed.
//		noErr					Otherwise.
//
//	Operation:
//		If a handle is provided, we set it to be nonpurgeable so that subsequent oper-
//		ations don't blow it away, and we note it's current handle state.  Then, we get
//		a reference number and a pointer to a free output record.  If successful, we
//		initialize the output record, thereby opening the sound channel.  Then, if a
//		sound was provided, we move it high, lock it, and call SHBeginPlayback to begin
//		asynchronous playback and queue up a callback.  Finally, we return the reference
//		number if the caller wants it.  If the sound wasn't provided (i.e. nil), every-
//		thing is the same except there's no SHBeginPlayback call.
//
//	IMPORTANT:
//		DO NOT start a sound handle playing with SHPlayByHandle, get it's channel with
//		SHGetChannel, and then do another SndPlay on that channel!  This will crash on
//		pre-7.0 systems. If you want a channel, use SHPlayByHandle with a _NIL_ handle.
//		See the comments for SHBeginPlayback.
//		
//=======================================================================================
pascal OSErr SHPlayByHandle( Handle sound, long *refNum )
{
	char		oldhandleState;
	short		ref;
	OSErr		error;
	SHOutPtr	outRec;
	
	// Save sound handle's flags, then set it to be nonpurgeable.  This is because some
	// of the Sound Manager stuff below may cause memory allocation, which could cause
	// the handle to be purged.  We don't want that, since we're going to start playing
	// it real soon.  If the caller gave us nil for a sound handle, that means he's
	// really just interested in having the sound channel.  So, we go on our merrory way
	// without a sound handle.
	if( sound != nil )
	{
		oldhandleState = SHGetState( sound );
		HNoPurge(sound );
	} else oldhandleState = 0;
		
	// Now, let's get a reference number and an output record.
	ref = SHNewRefNum();
	error = SHNewOutRec( &outRec );
	if( error != noErr )
	{
		if( sound != nil )
			HSetState( sound, oldhandleState );
		return error;
	}
	
	// Now let's fill in the output record with all the pertinent information.  This
	// routine also initializes the sound channel and flags outRec as "in use."
	error = SHInitOutRec( outRec, ref, sound, oldhandleState );
	if( error != noErr )
	{
		if( sound != nil )
			HSetState( sound, oldhandleState );
		SHReleaseOutRec( outRec );
		return error;
	}
	
	// At this point, we're in pretty good shape.  We've got a reference number, an
	// initialized output record, and the sound handle.  Let's get whacky.
	if( sound != nil )
	{			// if we've got a sound, lock and begin playback
		MoveHHi( sound );
		HLock( sound );
		error = SHBeginPlayback( outRec );
		if( error != noErr )
	{
			HSetState( sound, oldhandleState );
			SHReleaseOutRec( outRec );
			return error;
		}
	else
	{
			if( refNum != nil )		// refNum is optional -  the caller may not want it
				*refNum = ref;
			return error;
		}
	}
	else
	{						// if there's no sound, go ahead and return noErr
		if( refNum != nil )			// refNum is optional -  the caller may not want it
			*refNum = ref;
		return error;
	}
}

//=======================================================================================
//
//	SHOutPtr SHOutRecFromRefNum( long refNum )
//
//	Summary:
//		This routine finds that SHOutRec that is associated with a given refNum, if any.
//
//	Scope:
//		Private.
//
//	Parameters:
//		refNum		The output reference number in question.
//
//	Returns:
//		A pointer to the associated SHOutRec, if any, or nil, if none was found with a
//		reference number matching refNum.
//
//	Operation:
//		This handy routine searches the output record array looking for an output record
//		that has the given reference number.  If one is found, a pointer to it is
//		returned.  If not, then nil is returned.
//
//=======================================================================================
SHOutPtr SHOutRecFromRefNum( long refNum )
{
	short i;
	
	// Search for the specified refNum
	for( i = 0; i < gsSHOutVars.numOutRecs; i++ )
		if( gsSHOutVars.outArray[i].inUse && gsSHOutVars.outArray[i].refNum == refNum )
			break;
	
	// If we found it, return a pointer to that record, otherwise, nil.
	if( i == gsSHOutVars.numOutRecs )
		return nil;
	else return &gsSHOutVars.outArray[i];
}

//=======================================================================================
//
//	void SHPlayStopByRec( SHOutPtr outRec )
//
//	Summary:
//		This routine stops sound playback on the channel associated with the given
//		output record.
//
//	Scope:
//		Private.
//
//	Parameters:
//		outRec		A pointer to the output record whose sound should be stopped.
//
//	Returns:
//		Nothing.
//
//	Operation:
//		This routine sends two immediate sound commands to the channel in the given
//		output record.  The flushCmd gets rid of any unprocessed commands from the
//		queue subsequent to the one currently being processed.  The quietCmd, when sent
//		with SndDoImmediate, immediately quiets the channel.  Note that there might not
//		be any synthesizer yet associate with this channel, and in that case, these
//		commands are just eaten by the Sound Manager.
//
//=======================================================================================
void SHPlayStopByRec( SHOutPtr outRec )
{
	SndCommand	cmd;

	// Dump the rest of the commands in the queue (including our callbackCmd).
	cmd.cmd = flushCmd;
	cmd.param1 = 0;
	cmd.param2 = 0;
	SndDoImmediate( &outRec->channel, &cmd );
	
	// Shut up this minute!  Go to your room!  No dessert tonight for you, little boy.
	cmd.cmd = quietCmd;
	cmd.param1 = 0;
	cmd.param2 = 0;
	SndDoImmediate( &outRec->channel, &cmd );
	
	// It is now safe to just manually dump our channel (we'll just skip the whole
	// callback thing in this case).
	SHReleaseOutRec( outRec );
}

//=======================================================================================
//
//	pascal OSErr SHPlayStop( long refNum )
//
//	Summary:
//		This routine stops playback on the output record referrored to by refNum.
//
//	Scope:
//		Public.
//
//	Parameters:
//		refNum		The output reference number of the sound the caller wants stopped.
//
//	Returns:
//		kSHErrBadRefNum		If the reference number does not refer to any current output
//							record.  (Note that this is not necessarily bad.  If they
//							try to stop a sound that has already stopped by its own
//							accord, this error will be returned.  Usually you can call
//							this routine and ignore the error. )
//		noErr				Otherwise.
//
//	Operation:
//		This routine calls SHOutRecFromRefNum to try to find the output record that is
//		associated with refNum.  If one is found, we call SHPlayStopByRec to stop
//		playback for that output record.
//
//=======================================================================================
pascal OSErr SHPlayStop( long refNum )
{
	SHOutPtr	outRec;
	
	// Look for the associated output record.
	outRec = SHOutRecFromRefNum( refNum );
	
	// If we found it, call SHPlayStopByRec to stop playback.
	if( outRec != nil )
	{
		SHPlayStopByRec( outRec );
		return noErr;
	}
	else return kSHErrBadRefNum;
}

//=======================================================================================
//
//	pascal OSErr SHPlayStopAll( void )
//
//	Summary:
//		This routine stops all sound that the Helper initiated.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		noErr		This may return something more interesting in the future.
//
//	Operation:
//		This routine iterates through all the output records looking for records that
//		are in use.  When an in-use record is found, playback on that record is stopped
//		by calling SHPlayStopByRec.  Errors are ignored.
//
//=======================================================================================
pascal OSErr SHPlayStopAll( void )
{
	// Look for output records that are in use and stop their playback with
	// SHPlayStopByRec.
	for( short i = 0; i < gsSHOutVars.numOutRecs; i++ )
		if( gsSHOutVars.outArray[i].inUse )
			SHPlayStopByRec( &gsSHOutVars.outArray[i] );
	
	return noErr;
}

//=======================================================================================
//
//	pascal OSErr SHPlayPause( long refNum )
//
//	Summary:
//		This routine pauses playback of sound associated with refNum.
//
//	Scope:
//		Public.
//
//	Parameters:
//		refNum		The output reference number of the sound the caller wants paused.
//
//	Returns:
//		OSErr				If a SndDoImmediate fails.
//		kSHErrBadRefNum		If the given reference number is not associated with any
//							current output record.
//		kSHErrAlreadyPaused	If the sound is already paused.
//
//	Operation:
//		For a sound like "Simple beep," which is a long sequence of sound commands,
//		pausing a sound means "pausing sound command queue processing," and is performed
//		with the pauseCmd.  Sampled sounds, like "Wild Eep," usually consist of a single
//		bufferCmd to play back the sampled sound.  The pauseCmd is ineffective with
//		sampled sounds because the sound is paused after the current command is processed
//		(the bufferCmd), so the entire sound would be played.  This is rarely what the
//		caller wants.  So, we've got a little trick in here to pause sampled sounds.  If
//		you set a sampled sound's sample playback rate to zero, it effectively pauses the
//		sampled sound in its tracks, mid-bufferCmd (which is what the caller probably
//		wants).
//
//		There is really no officially sanctioned way to know whether a sound is command-
//		type or sampled without parsing the sound.  However, any synthesizer that returns
//		a non-zero rate from a getRateCmd call will be able to understand a rateCmd.  So
//		we try a getRateCmd, and if we get a non-zero rate, send a rateCmd to set the
//		playback rate to zero.  If we get zero from the getRateCmd, we assume that the
//		synthesizer cannot understand the getRateCmd, and instead use a pauseCmd to pause
//		the sound.  This is the only offically sanctioned universal method of pausing any
//		sound.
//
//		If the sound was successfully paused, the output record's paused flag is set.
//
//=======================================================================================
pascal OSErr SHPlayPause( long refNum )
{
	SHOutPtr	outRec;
	SndCommand	cmd;
	OSErr		error;
	
	outRec = SHOutRecFromRefNum(refNum );
	if( outRec != nil )
	{
		// Don't bother with this if we're already paused.
		if( outRec->paused )
			return kSHErrAlreadyPaused;
		
		// Get the current playback rate for this sound.
/*		cmd.cmd = getRateCmd;
		cmd.param1 = 0;
		cmd.param2 = (long) &outRec->rate;
		error = SndDoImmediate( &outRec->channel, &cmd );
		if( error != noErr )
			return error;
*/		
		// Now pause with either a rateCmd or a pauseCmd, as appropriate
		cmd.param1 = 0;
		cmd.param2 = 0;
/*		if( outRec->rate != 0 )
		{
			// If we get something non-zero, it's safe to assume that whatever
			// synthesizer we're talking to will be able to understand a rateCmd to
			// restore the rate (probably the sampled synthesizer).  To pause the
			// sound, we'll set the rate to zero.
			cmd.cmd = rateCmd;
			error = SndDoImmediate( &outRec->channel, &cmd );
			if( error != noErr )
				return error;
		}
		else
		{
*/			// This synthesizer doesn't understand rateCmds.  So instead we'll just
			// pause command queue processing with a pauseCmd.  This is how command-type
			// sounds (e.g. Simple Beep) are paused.
			cmd.cmd = pauseCmd;
			error = SndDoImmediate( &outRec->channel, &cmd );
			if( error != noErr )
				return error;
/*		}
*/
		outRec->paused = true;
		return error;
	}
	else return kSHErrBadRefNum;
}

//=======================================================================================
//
//	pascal OSErr SHPlayContinue( long refNum )
//
//	Summary:
//		This routine continues playback of a previously paused sound.
//
//	Scope:
//		Public.
//
//	Parameters:
//		refNum		The refNum of the sound the caller wants playback continued on.  This
//					should be the refNum of a sound that was previously paused with
//					SHPlayPause.
//
//	Returns:
//		OSErr					If the SndDoImmediate fails.
//		kSHErrBadRefNum			If the refNum doesn't refer to any current output record.
//		kSHErrAlreadyContinued	If the sound is not paused.
//
//	Operation:
//		First SHPlayContinue gets a pointer to the output record (if any) that refNum
//		refers to.  If found, and that sound is paused, we check the output record's
//		rate field.  If non-zero, then the sound was paused with rateCmd, so we send 
//		another rateCmd to restore its playback rate.  Otherwise, we send a resumeCmd
//		(to resume command-queue processing).  (See the comments for SHPlayPause for
//		details on the two methods of pausing sound.)  If the resumeCmd is successful,
//		we clear the output record's paused flag.
//
//=======================================================================================
pascal OSErr SHPlayContinue( long refNum )
{
	SHOutPtr	outRec;
	SndCommand	cmd;
	OSErr		error;
	
	outRec = SHOutRecFromRefNum(refNum );
	if( outRec != nil )
	{
		// Don't even bother with this stuff if the channel isn't paused.
		if( !outRec->paused )
			return kSHErrAlreadyContinued;
		
		// Now continue playback with a rateCmd or a resumeCmd, as appropriate.
		cmd.param1 = 0;
/*		if( outRec->rate != 0 )
		{
			// Resume sampled sound playback by restoring the synthesizer's playback
			// rate with a rateCmd.
			cmd.cmd = rateCmd;
			cmd.param2 = outRec->rate;
			error = SndDoImmediate( &outRec->channel, &cmd );
			if( error != noErr )
				return error;
		}
		else
		{
*/			// Resume sound queue processing with a resumeCmd.
			cmd.cmd = resumeCmd;
			cmd.param2 = 0;
			error = SndDoImmediate( &outRec->channel, &cmd );
			if( error != noErr )
				return error;
/*		}
*/		
		outRec->paused = false;
		return error;
	}
	else return kSHErrBadRefNum;
}

//=======================================================================================
//
//	pascal SHPlayStat SHPlayStatus( long refNum )
//
//	Summary:
//		This routine returns a status value for the sound associated with refNum.
//
//	Scope:
//		Public.
//
//	Parameters:
//		refNum		The sound for which the caller wishes status information.
//
//	Returns:
//		shpError = -1		If refNum has never been used (and is therefore invalid).
//		shpFinished = 0		If the sound associated with refNum has completed.
//		shpPaused = 1		If the sound associated with refNum is currently paused.
//		shpPlaying = 2		If the sound associated with refNum is currently playing.
//
//	Operation:
//		First we check to see if refNum is greater than or equal to our next output
//		reference number.  If it is, then this reference number is definitely invalid,
//		so we return shpError.  Otherwise, we look refNum up with SHOutRecFromRefNum.
//		If no record is found (but we know that refNum has been used in the past), we
//		can assume that the sound has completed, and return shpFinished.  Otherwise,
//		the sound is currently playing or is paused, so we return either shpPaused or
//		shpPlaying based on the value of the output record's paused flag.
//
//=======================================================================================
pascal SHPlayStat SHPlayStatus( long refNum )
{
	SHOutPtr	outRec;
	
	if( refNum >= gsSHOutVars.nextRef )
		return shpError;
	else
	{
		outRec = SHOutRecFromRefNum( refNum );
	
		if( outRec != nil )
		{
			// We found an SHOutRec for the guy's ref num, (so it's in use).
			return outRec->paused? shpPaused:shpPlaying;
		}
		else
		{
			// Although we've used the reference number in the past, it's not in use, so
			// we can assume whatever sound it was associated has since stopped.  So,
			// we'll return shpFinished in this case.
			return shpFinished;
		}
	}
}

//=======================================================================================
//
//	pascal OSErr SHGetChannel( long refNum, SndChannelPtr *channel )
//
//	Summary:
//		This routine allows the caller to retrieve a pointer to the sound channel that
//		is associated with the given refNum.
//
//	Scope:
//		Public.
//
//	Parameters:
//		refNum		The sound for which the caller wants to retrieve a sound channel
//					pointer.
//		channel		A pointer to a SndChannelPtr.  This VAR parameter is where the sound
//					channel address is stored if it is found.
//
//	Returns:
//		kSHErrBadRefNum		If refNum doesn't refer to any current output record.
//		noErr				Otherwise.
//
//	Operation:
//		This routine is provided to allow more advanced callers to have access to the
//		sound channel associated with a reference number.  This could be useful, for
//		instance, if the caller wanted to send sound commands to the channel, and only
//		use the Helper to manage the channel (but not the sound).  A good example of
//		this is continuous background music.  You make a sound with a soundCmd and a
//		loop.  Then you open a channel by doing a SHPlayByHandle(nil, &ref), then get
//		the channel pointer by calling SHGetChannel, manually PlaySnd the background
//		music sound (which should contain a soundCmd to install the music as a voice),
//		then send a freqCmd to start the music playing.  It'll keep looping until a
//		quietCmd comes along.  (SEE NOTE BELOW. )
//
//	IMPORTANT:
//		If you use the above-described technique to provide looped background sound, it
//		is important to note that when you change the background music (e.g. from one
//		song to the next), you should SHPlayStop the channel, and allocate a new channel
//		with new calls to SHPlayByHandle(nil, &ref)/SHGetChannel.  DO NOT make another
//		SndPlay call on the same channel to change the sound, because this will crash on
//		pre-7.0 Systems.
//
//=======================================================================================
pascal OSErr SHGetChannel( long refNum, SndChannelPtr *channel )
{
	SHOutPtr	outRec;
	
	// Look for the output record associated with refNum.
	outRec = SHOutRecFromRefNum( refNum );
	
	// If we found one, return a pointer to the sound channel.
	if( outRec != nil )
	{
		*channel = &outRec->channel;
		return noErr;
	}
	else return kSHErrBadRefNum;
}

//=======================================================================================
//
//	OSErr SHGetDeviceSettings( long inRefNum, short *numChannels, Fixed *sampleRate, short *sampleSize, OSType *compType )
//
//	Summary:
//		This routine gets several parameters from an open sound input device.
//
//	Scope:
//		Private.
//
//	Parameters:
//		inRefNum		The sound input device's input reference number.
//		numChannels		A VAR parameter in which the number of channels is returned.
//		sampleRate		A VAR parameter in which the sample rate (in Hz) is returned.
//		sampleSize		A VAR parameter in which the number of bits/sample is returned.
//		compType		A VAR parameter in which the compression type is returned.
//
//	Returns:
//		OSErr			If any of the SPBGetDeviceInfo calls fail.
//		noErr			Otherwise.
//
//	Operation:
//		This routine does four SPBGetDeviceInfo calls to retrieve the number of channels
//		the sample rate, the sample size, and the compression type for the input device
//		referrored to by inRefNum.  This routine is almost verbatim out of Inside Macintosh
//		Volume 6.
//
//=======================================================================================
OSErr SHGetDeviceSettings( long inRefNum, short *numChannels, Fixed *sampleRate, short *sampleSize, OSType *compType )
{
	OSErr error = noErr;
	
	// Hit on that sound input device.
	error = SPBGetDeviceInfo( inRefNum, siNumberChannels, (Ptr) numChannels );
	if( error != noErr ) return error;
	error = SPBGetDeviceInfo( inRefNum, siSampleRate, (Ptr) sampleRate );
	if( error != noErr ) return error;
	error = SPBGetDeviceInfo(inRefNum, siSampleSize, (Ptr) sampleSize );
	if( error != noErr ) return error;
	error = SPBGetDeviceInfo(inRefNum, siCompressionType, (Ptr) compType );
	return error;
}

//=======================================================================================
//
//	pascal OSErr SHRecordStart( short maxK, OSType quality, Boolean *doneFlag )
//
//	Summary:
//		This routine initiates asynchronous sound recording.
//
//	Scope:
//		Public.
//
//	Parameters:
//		maxK		The amount of memory (in 1024-byte chunks) the caller wishes to
//					preallocate for the user to record into.
//		quality		One of the standard Macintosh Sound Input Manager qualities: 'good',
//					'betr', or 'best'.
//		doneFlag	A pointer to a Boolean by which the Helper will inform the caller
//					that recording has finished and an SHGetRecordedSound call is in
//					order.  If nil, then the caller will not be directly informed when
//					recording is complete, but will instead have to call SHRecordStatus
//					to find out.
//
//	Returns:
//		OSErr		If any of the stages fail.
//		noErr		Otherwise.
//
//	Operation:
//		This routine initiates asynchronous recording.  There are eight stages, each
//		of which could fail.  So, each state checks that the previous stage was success-
//		ful, so errors fall through the bottom.  Along the way, the local bools
//		deviceOpened and allocated are set when the sound input device is opened and
//		the sound input buffer is allocated, respectively.  If one or more of these flags
//		is set at the end of the routine AND there's been an error, then device closure/
//		deallocation is performed as required.  The stages are as follows:
//
//			1. Open the sound input device.
//			2. Ask the device if it can do asynchronous recording.
//			3. Allocate the sound input buffer, as specified by the maxK parameter.
//			4. Turn on metering and set the recording quality as specified by the
//			   quality parameter.
//			5. The fifth stage is to grab (and save inside the gsInVars structure) the
//			   default number of channels, sample rate, sample size, and compression
//			   type.  We'll use the saved values later when we go to install a more
//			   accurate header into the sound, at completion time.
//			6. Create a sound header in the sound input buffer.
//			7. Fill out the sound input parameter block inPB.  Note that we put the
//			   application A5 into the userLong field of the parameter block, so that
//			   SHRecordCompletion can access our globals.  Also note that
//			   SHRecordCompletion is installed directly as the callback routine.  This
//			   stage cannot fail, and sets error to noErr.
//			8. The eighth and final stage is to set various flags such that we know
//			   we're recording, and calls SPBRecord to initiate the asynchronous
//			   recording process.  The reason we set our flags before we make the
//			   SPBRecord call is to avoid a "race" condition, where the recording could
//			   (theoretically) complete virtually immediately and our callback routine
//			   would get called before the flags were set up, thus confusing it.  To
//			   avoid this, set the flags first, then the error handler code can reset
//			   them if the recording failed.
//
//		If an error occurred along the way, the sound input device may be closed, and/or
//		the sound input buffer may be deallocated.
//
//=======================================================================================
pascal OSErr SHRecordStart( short maxK, OSType quality, Boolean *doneFlag )
{
	Boolean	deviceOpened = false;
	Boolean	allocated = false;
	
	OSErr error = noErr;
	short	canDoAsync;
	short	metering;
	long	allocSize;
	
	// 1. Try to open the current sound input device
	error = SPBOpenDevice( nil, siWritePermission, &gsSHInVars.inRefNum );
	if( error == noErr )
		deviceOpened = true;

	// 2. Now let's see if this device can even handle asynchronous recording.
	if( error == noErr )
	{
		error = SPBGetDeviceInfo( gsSHInVars.inRefNum, siAsync, (Ptr) &canDoAsync );
		if( error == noErr && !canDoAsync )
			error = kSHErrNonAsychDevice;
	}
	
	// 3. Try to allocate memory for the guy's sound.
	if( error == noErr )
	{
		allocSize = (maxK * 1024) + kSHHeaderSlop;
		gsSHInVars.inHandle = NewHandle(allocSize );
		if( gsSHInVars.inHandle == nil )
	{
			error = MemError();
			if( error == noErr )
				error = memFullErr;
		}
		if( error == noErr )
			allocated = true;
	}
		
	// 4. Set up various recording parameters (metering and quality )
	if( error == noErr )
	{
		metering = 1;
		SPBSetDeviceInfo( gsSHInVars.inRefNum, siLevelMeterOnOff, (Ptr) &metering );
		error = SPBSetDeviceInfo( gsSHInVars.inRefNum, siRecordingQuality, (Ptr) &quality );
	}
	
	// 5. Call SHGetDeviceSettings to determine a bunch of information we'll need to
	// make a header for this sound.
	if( error == noErr )
	{
		error = SHGetDeviceSettings(gsSHInVars.inRefNum, &gsSHInVars.numChannels,
			&gsSHInVars.sampleRate, &gsSHInVars.sampleSize, &gsSHInVars.compType );
	}
	
	// 6. Create a header for this sound.
	if( error == noErr )
	{
		error = SetupSndHeader((SndListHandle)gsSHInVars.inHandle, gsSHInVars.numChannels, gsSHInVars.sampleRate, gsSHInVars.sampleSize,
			gsSHInVars.compType, kSHBaseNote, allocSize, &gsSHInVars.headerLength );
	}
	
	// 7. Lock the input sound handle and set up the input parameter block.
	if( error == noErr )
	{
		MoveHHi( gsSHInVars.inHandle );
		HLock( gsSHInVars.inHandle );
		
		allocSize -= gsSHInVars.headerLength;
		gsSHInVars.inPB.inRefNum = gsSHInVars.inRefNum;
		gsSHInVars.inPB.count = allocSize;
		gsSHInVars.inPB.milliseconds = 0;
		gsSHInVars.inPB.bufferLength = allocSize;
		gsSHInVars.inPB.bufferPtr = *gsSHInVars.inHandle + gsSHInVars.headerLength;
		gsSHInVars.inPB.completionRoutine = gsSHRecordCompletionUPP;
		gsSHInVars.inPB.interruptRoutine = nil;
		gsSHInVars.inPB.userLong = 0L;
		gsSHInVars.inPB.error = noErr;
		gsSHInVars.inPB.unused1 = 0;
		
		error = noErr;
	}
	
	// 8. Finally, if all went well, set our recording flag, make sure our record
	// completion flag is clear, and initiate asychronous recording.
	if( error == noErr )
	{
		gsSHInVars.recording = true;
		gsSHInVars.recordComplete = false;
		gsSHInVars.appComplete = doneFlag;
		gsSHInVars.paused = false;
		if( gsSHInVars.appComplete != nil )
			*gsSHInVars.appComplete = false;
		
		error = SPBRecord(&gsSHInVars.inPB, kSHAsync );
	}
	
	// Now clean up any errors that might have occurred.
	if( error != noErr )
	{
		gsSHInVars.recording = false;
		if( deviceOpened )
			SPBCloseDevice( gsSHInVars.inRefNum );
		if( allocated )
		{
			DisposeHandle( gsSHInVars.inHandle );
			gsSHInVars.inHandle = nil;
		}
	}
	
	return error;
}

//=======================================================================================
//
//	pascal OSErr SHGetRecordedSound( Handle *theSound )
//
//	Summary:
//		This routine returns the sound handle from the last sound the Helper recorded.
//
//	Scope:
//		Public.
//
//	Parameters:
//		theSound		A pointer to a Handle by which to return the sound handle.
//
//	Returns:
//		kSHErrNoRecording		If there IS NO "last recorded sound"
//		OSErr					If recording stopped because of an error
//		noErr					Otherwise.
//
//	Operation:
//		This routine returns the sound handle (stored in the inHandle field of the
//		gsSHInVars struct) from the last sound that was recorded by the Helper.  If
//		the recording died by an error (other than abortErr), then the error is returned
//		and *theSound is set to nil.  SHGetRecordedSound is the method by which you
//		retrieve a sound handle, once you know (by whatever means) that recording is
//		complete.
//
//=======================================================================================
pascal OSErr SHGetRecordedSound( Handle *theSound )
{
	if( gsSHInVars.recordComplete )
	{
		if( gsSHInVars.recordErr != noErr )
		{
			*theSound = nil;
			return gsSHInVars.recordErr;
		}
		else
		{
			*theSound = gsSHInVars.inHandle;
			return noErr;
		}
	}
	else
	{
		*theSound = nil;
		return kSHErrNoRecording;
	}
}

//=======================================================================================
//
//	pascal OSErr SHRecordStop( void )
//
//	Summary:
//		This routine immediately stops sound recording.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		OSErr		Whatever SPBStopRecording returns.
//
//	Operation:
//		This routine simply calls SPBStopRecording to immediately stop sound recording.
//		It sets the parameter block's error code to abortErr, and calls the callback
//		routine.  Use this routine to implement a "stop" button.
//
//=======================================================================================
pascal OSErr SHRecordStop( void )
{
	if( gsSHInVars.recording )
		return SPBStopRecording(gsSHInVars.inRefNum);
	return noErr;
}

//=======================================================================================
//
//	pascal OSErr SHRecordPause( void )
//
//	Summary:
//		This routine pauses sound recording.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		kSHErrNotRecording		If we're not recording right now.
//		kSHErrAlreadyPaused		If recording is already paused.
//		OSErr					Whatever SPBPauseRecording returns.
//
//	Operation:
//		This routine pauses sound recording if we ARE recording and we're not already
//		paused.  Use this routine to implement a "pause" button.
//
//=======================================================================================
pascal OSErr SHRecordPause( void )
{
	OSErr error = noErr;
	if( gsSHInVars.recording )
	{
		if( !gsSHInVars.paused )
	{
			error = SPBPauseRecording( gsSHInVars.inRefNum );
			gsSHInVars.paused = (error == noErr);
			return error;
		}
		else return kSHErrAlreadyPaused;
	}
	else return kSHErrNotRecording;
}

//=======================================================================================
//
//	pascal OSErr SHRecordContinue( void )
//
//	Summary:
//		This routine resumes recording when recording has previously been paused.
//
//	Scope:
//		Public.
//
//	Parameters:
//		None.
//
//	Returns:
//		kSHErrNotRecording		If we're not recording right now.
//		kSHErrAlreadyContinued	If we're not paused.
//		OSErr					Whatever SPBResumeRecording returns.
//
//	Operation:
//		This routine continues sound recording if we ARE recording and we've been
//		previously paused.  Use this routine to implement a "unpause" button.
//
//=======================================================================================
pascal OSErr SHRecordContinue( void )
{
	OSErr error = noErr;
	
	if( gsSHInVars.recording )
	{
		if( gsSHInVars.paused )
		{
			error = SPBResumeRecording( gsSHInVars.inRefNum );
			gsSHInVars.paused = !(error == noErr);
			return error;
		}
		else return kSHErrAlreadyContinued;
	}
	else return kSHErrNotRecording;
}

//=======================================================================================
//
//	pascal OSErr SHRecordStatus( SHRecordStatusRec *recordStatus )
//
//	Summary:
//		This routine returns status information on sound that is being recorded.
//
//	Scope:
//		Public.
//
//	Parameters:
//		recordStatus	A pointer to a SHRecordStatusRec into which to store the
//						recording status.
//
//	Returns:
//		kSHErrNotRecording		If we're not recording right now.
//		OSErr					Whatever SPBGetRecordingStatus returns.
//		noErr					Otherwise.
//
//	Operation:
//		If we're currently recording, we call SPBGetRecordingStatus.  It tells us lots
//		of handy things, most of which we return via recordStatus, then we give a status
//		of either shrPaused or shrRecording, depending upon the state of the
//		gsSHInVars.paused flag.  If recording is complete, we return shrFinished.  If an
//		error occurs, we give a status of shrError.
//
//=======================================================================================
pascal OSErr SHRecordStatus( SHRecordStatusRec *recordStatus )
{
	short			recStatus;
	OSErr			error = noErr;
	unsigned long	totalSamplesToRecord,numberOfSamplesRecorded;
	
	if( gsSHInVars.recording )
	{
		error = SPBGetRecordingStatus( gsSHInVars.inRefNum, &recStatus,
			&recordStatus->meterLevel, &totalSamplesToRecord, &numberOfSamplesRecorded,
			&recordStatus->totalRecordTime, &recordStatus->currentRecordTime );
		if( error == noErr )
			recordStatus->recordStatus = ( gsSHInVars.paused? shrPaused:shrRecording );
		else recordStatus->recordStatus = shrError;
		return error;
	}
	else if( gsSHInVars.recordComplete )
	{
		recordStatus->recordStatus = shrFinished;
		recordStatus->meterLevel = 0;
		// Don't know about the other fields -- just leave 'em
		return error;
	}
	else return kSHErrNotRecording;
}
