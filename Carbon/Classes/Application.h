#include "ResKnife.h"

#ifndef _ResKnife_Application_
#define _ResKnife_Application_

/*!
	@header			Application
	@discussion		The Application.cpp file manages all critical workings to keep the program running, these include initalizing the environment, maintaining an event queue and parsing received events. It also manages the menubar.
*/

  /***********************/
 /* EVENT INITALIZATION */
/***********************/

/*!
	@function		InitToolbox
*/
OSStatus			InitToolbox( void );
/*!
	@function		InitMenubar
*/
OSStatus			InitMenubar( void );
/*!
	@function		InitAppleEvents
*/
OSStatus			InitAppleEvents( void );
/*!
	@function		InitCarbonEvents
*/
OSStatus			InitCarbonEvents( void );
/*!
	@function		InitGlobals
*/
OSStatus			InitGlobals( void );

  /*****************/
 /* EVENT PARSING */
/*****************/

#if !TARGET_API_MAC_CARBON

/*!
	@function		ParseEvents
*/
OSStatus			ParseEvents( EventRecord *event );
/*!
	@function		ParseDialogEvents
*/
pascal Boolean		ParseDialogEvents( DialogPtr dialog, EventRecord *event, DialogItemIndex *itemHit );
/*!
	@function		ParseOSEvents
*/
OSStatus			ParseOSEvents( EventRecord *event );

#endif

/*!
	@function		ParseAppleEvents
*/
pascal OSErr		ParseAppleEvents( const AppleEvent *event, AppleEvent *reply, SInt32 refCon );

  /******************/
 /* EVENT HANDLING */
/******************/

#if !TARGET_API_MAC_CARBON

/*!
	@function		MouseDownEventOccoured
*/
OSStatus			MouseDownEventOccoured( EventRecord *event );
/*!
	@function		MouseUpEventOccoured
*/
OSStatus			MouseUpEventOccoured( EventRecord *event );
/*!
	@function		KeyDownEventOccoured
*/
OSStatus			KeyDownEventOccoured( EventRecord *event );
/*!
	@function		KeyRepeatEventOccoured
*/
OSStatus			KeyRepeatEventOccoured( EventRecord *event );
/*!
	@function		KeyUpEventOccoured
*/
OSStatus			KeyUpEventOccoured( EventRecord *event );
/*!
	@function		UpdateEventOccoured
*/
OSStatus			UpdateEventOccoured( EventRecord *event );
/*!
	@function		ActivateEventOccoured
*/
OSStatus			ActivateEventOccoured( EventRecord *event );
/*!
	@function		IdleEvent
*/
OSStatus			IdleEvent( void );

#endif

/*!
	@function		QuitResKnife
*/
void				QuitResKnife( void );

  /*****************/
 /* MENU HANDLING */
/*****************/

#if TARGET_API_MAC_CARBON

/*!
	@function		CarbonEventUpdateMenus
*/
pascal				OSStatus CarbonEventUpdateMenus( EventHandlerCallRef callRef, EventRef event, void *userData );
/*!
	@function		CarbonEventParseMenuSelection
*/
pascal OSStatus		CarbonEventParseMenuSelection( EventHandlerCallRef callRef, EventRef event, void *userData );
/*!
	@function		DefaultIdleTimer
*/
pascal void			DefaultIdleTimer( EventLoopTimerRef timer, void *data );

#else

/*!
	@function		UpdateMenus
*/
OSStatus			UpdateMenus( WindowRef window );
/*!
	@function		ParseMenuSelection
*/
OSStatus			ParseMenuSelection( UInt16 menu, UInt16 item );

#endif

  /****************/
 /* APPLE EVENTS */
/****************/

/*!
	@function		AppleEventSendSelf
*/
OSStatus			AppleEventSendSelf( DescType eventClass, DescType eventID, AEDescList list );
/*!
	@function		GotRequiredParams
*/
Boolean				GotRequiredParams( const AppleEvent *event );
/*!
	@function		AppleEventOpen
*/
OSStatus			AppleEventOpen( const AppleEvent *event );
/*!
	@function		AppleEventPrint
*/
OSStatus			AppleEventPrint( const AppleEvent *event );

  /*********************/
 /* NIBÑBASED WINDOWS */
/*********************/

/*!
	@function		ShowAboutBox
*/
OSStatus			ShowAboutBox( void );
/*!
	@function		ShowPrefsWindow
*/
OSStatus			ShowPrefsWindow( void );
/*!
	@function		PrefsTabEventHandler
*/
pascal OSStatus		PrefsTabEventHandler( EventHandlerCallRef handlerRef, EventRef event, void* userData );

#endif