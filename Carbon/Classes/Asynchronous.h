#if defined(__MWERKS__)
	#include <Resources.h>
	#include <Sound.h>
#else
	#include <Carbon/Carbon.h>
#endif

// enumerations
typedef enum
{
	shpError	= -1,
	shpFinished	= 0,
	shpPaused	= 1,
	shpPlaying	= 2
}	SHPlayStat;

typedef enum
{
	shrError	= -1,
	shrFinished	= 0,
	shrPaused	= 1,
	shrRecording = 2
}	SHRecordStat;

// Sound Helper error codes
enum
{
	kSHErrOutaChannels = 1,		// No more output records are available
	kSHErrBadRefNum,			// Invalid reference number
	kSHErrNonAsychDevice,		// Input device can't handle asynchronous input
	kSHErrNoRecording,			// There's no recording to return
	kSHErrNotRecording,			// Not allowed because we're not recording
	kSHErrAlreadyPaused,		// Already paused
	kSHErrAlreadyContinued		// Already continued
};

// Contants used by the Asynchronous Sound Helper
const SInt16	kSHDefChannels		= 4;		// Default number of channels to preallocate
const SInt16	kSHCompleteSig		= 'SH';		// Flag we use to know a "true" completion callback
const SInt32	kSHComplete			= 'SHcp';	// Flag that a given channel has completed playback
const SInt16	kSHHeaderSlop		= 100;		// Extra bytes for the sound header when recording
const SInt16	kSHBaseNote			= 60;		// Middle C base note for new recordings
const SInt16	kSHSyncWaitTimeout	= 60;		// Ticks to sync-wait when killing the Helper

// Constants that should be in Sound.h but aren't
const SInt16	kSHNoSynth			= 0;		// Don't associate any synth to this channel
const SInt16	kSHNoInit			= 0;		// No specific initialization
const SInt8		kSHQuietNow			= true;		// Stop playing this sound immediately
const SInt8		kSHAsync			= true;		// Play asynchronously
const SInt8		kSHWait				= false;	// Wait for there to be enough room in the queue

// structures
typedef struct
{
	SHRecordStat	recordStatus;		// Current record status
	unsigned long	totalRecordTime;	// Total (maximum) record time in ms
	unsigned long	currentRecordTime;	// Current recorded time in ms
	short			meterLevel;			// 0..255, the current input level
}	SHRecordStatusRec;

typedef struct
{
	SndChannel	channel;			// Our sound channel
	long		refNum;				// Our Helper ref num
	Handle		sound;				// The sound we're playing
	Fixed		rate;				// The rate at which a sampled sound is playing
	char		handleState;		// The handle state to restore this handle to
	Boolean		inUse;				// Tells whether this SHOutRec is in use
	Boolean		paused;				// Tells whether this sound is currently paused
}	SHOutRec,	*SHOutPtr;

typedef struct
{
	short		numOutRecs;			// The number of output records in outArray
	SHOutRec	*outArray;			// Our pre-allocated output records
	long		nextRef;			// The next available output reference number
}	SHOutputVars;

typedef struct
{
	long		inRefNum;			// Sound Input Manager's device refNum
	SPB			inPB;				// The input parameter block
	Handle		inHandle;			// The handle we're recording into
	short		headerLength;		// The length of the sound's header
	Boolean		recording;			// Tells whether we're actually recording
	Boolean		recordComplete;		// Tells whether recording is complete
	OSErr		recordErr;			// Error, if error terminated recording
	short		numChannels;		// Number of channels for recording
	short		sampleSize;			// Sample size for recording
	Fixed		sampleRate;			// Sample rate for recording
	OSType		compType;			// Compression type for recording
	Boolean		*appComplete;		// Flag to caller that recording is done
	Boolean		paused;				// Tells whether recording has been paused
}	SHInputVars;

// Initialization, idle, and termination
pascal OSErr SHInitSoundHelper( Boolean *attnFlag, short numChannels );
pascal void SHIdle( void );
pascal void SHKillSoundHelper(void );

// Easy sound output
pascal OSErr SHPlayByID( short resID, long *refNum );
pascal OSErr SHPlayByHandle( Handle sound, long *refNum );
pascal OSErr SHPlayStop( long refNum );
pascal OSErr SHPlayStopAll( void );

// Advanced sound output
pascal OSErr SHPlayPause( long refNum );
pascal OSErr SHPlayContinue( long refNum );
pascal SHPlayStat SHPlayStatus( long refNum );
pascal OSErr SHGetChannel( long refNum, SndChannelPtr *channel );

// Easy sound input
pascal OSErr SHRecordStart( short maxK, OSType quality, Boolean *doneFlag );
pascal OSErr SHGetRecordedSound( Handle *theSound );
pascal OSErr SHRecordStop( void );

// Advanced sound input
pascal OSErr SHRecordPause( void );
pascal OSErr SHRecordContinue( void );
pascal OSErr SHRecordStatus( SHRecordStatusRec *recordStatus );