//
//  main.m
//  System7SoundPlayer
//
//  Created by Wevah on 2013-01-19.
//
//

@import XPC;
@import Foundation;
@import CoreServices.CarbonCore;
@import Carbon.CarbonSound;

static void System7SoundPlayer_peer_event_handler(xpc_connection_t peer, xpc_object_t event)
{
	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
		}
	} else {
		assert(type == XPC_TYPE_DICTIONARY);
		// Handle the message.
		NSLog(@"got dict");
		size_t length = 0;
		const char *data = xpc_dictionary_get_data(event, "soundData", &length);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations" // We have to use the deprecated function SndPlay
		SndListPtr sndPtr = (SndListPtr)NewPtr(length);
		memcpy(sndPtr, data, length);
		NSLog(@"data length: %lu", length);
		SndPlay(NULL, &sndPtr, false);
		DisposePtr((Ptr)sndPtr);
#pragma clang diagnostic pop
	}
}

static void System7SoundPlayer_event_handler(xpc_connection_t peer) 
{
	// By defaults, new connections will target the default dispatch
	// concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		System7SoundPlayer_peer_event_handler(peer, event);
	});
	
	// This will tell the connection to begin listening for events. If you
	// have some other initialization that must be done asynchronously, then
	// you can defer this call until after that initialization is done.
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_main(System7SoundPlayer_event_handler);
	return 0;
}
