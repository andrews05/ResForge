#import <Foundation/Foundation.h>

/*******************************/
/*****       WARNING       *****/
/*  This file is being broken  */
/*  apart into smaller files.  */
/*  If you want to change any  */
/*  methods here,  split them  */
/*  into new files beforehand. */
/*******************************/

/*!
@header
@abstract		Numerous small category methods on Foundation and AppKit classes.
@author			Nicholas Shanks
*/

@interface NSArray (NGSIndexExtensions)
/*!
@method			subarrayWithIndicies:
@updated		January 2004
@abstract		Returns an immutable array of the objects at the given indicies.
*/
- (NSArray *)subarrayWithIndicies:(NSIndexSet *)indicies;
@end

@interface NSArray (NGSKeyValueExtensions)
/*!
@method			indexOfFirstObjectReturningValue:forKey:
@updated		January 2003
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning the index of the first one encountered which itself returned the value passed in, according to <tt>isEqual:</tt>, or returns <tt>NSNotFound</tt> if no object matched for the given key/value pair. Mostly useful just for increasing code readability, as the methd is only one line long, but one that's not easy to understand at first glance.
@updated		2005-02-23 NGS: Removed unnecessary code, <tt>indexOfObject:</tt> already returns <tt>NSNotFound</tt> for me.
*/
- (NSInteger)indexOfFirstObjectReturningValue:(id)value forKey:(id)key;
/*!
@method			firstObjectReturningValue:forKey:
@updated		January 2003
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning the first one encountered which itself returned the value passed in, according to <tt>isEqual:</tt>. Returns <tt>nil</tt> if no matching object is found.
@updated		2005-02-23 NGS: Removed message to <tt>indexOfFirstObjectReturningValue:forKey:</tt>, incorperated that method's code into this one.
*/
- (id)firstObjectReturningValue:(id)value forKey:(id)key;
/*!
@method			objectsReturningValue:forKey:
@updated		January 2003
@abstract		Returns an array containing all objects in the receiver which have <tt>value</tt> set for key <tt>key</tt>.
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning a new array containing all objects which themselves returned the value passed in, according to <tt>isEqual:</tt>. If no objects matched, this method returns an empty array.
*/
- (NSArray *)objectsReturningValue:(id)value forKey:(id)key;
- (NSArray *)arrayByMakingObjectsPerformSelector:(SEL)selector withObject:(id)inObject;
@end

@interface NSCharacterSet (NGSNewlineExtensions)
/*!
@method			tabCharacterSet
@updated		March 2005
@abstract		Returns a character set containing only the horizontal and vertical tab characters (U+0009, U+000B).
*/
+ (NSCharacterSet *)tabCharacterSet;
@end

@interface NSNumber (NGSRangeExtensions)
/*!
@method			isWithinRange:
@updated		February 2003
*/
- (BOOL)isWithinRange:(NSRange)range;				// location <= self <= location+length
/*!
@method			isExclusivelyWithinRange:
@updated		February 2003
*/
- (BOOL)isExclusivelyWithinRange:(NSRange)range;	// location < self < location+length
/*!
@method			isBoundedByRange:
@updated		February 2003
*/
- (BOOL)isBoundedByRange:(NSRange)range;			// location <= self < location+length
@end

@interface NSString (NGSFSSpecExtensions)
/*!
@method			createFSRef
@updated		November 2002
@abstract		Returns an <tt>FSRef</tt> for the absolute path represented by the receiver. The caller is responsible for disposing of the <tt>FSRef</tt>.
*/
- (FSRef *)createFSRef;
/*!
@method			createFSSpec
@updated		November 2002
@abstract		Returns an <tt>FSSpec</tt> for the absolute path represented by the receiver. The caller is responsible for disposing of the <tt>FSSpec</tt>.
*/
- (FSSpec *)createFSSpec;
@end

@interface NSString (NGSBooleanExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
/*!
@method			boolValue
@updated		March 2001
@availability	In 10.4 and above, this method is available from the OS.
*/
- (BOOL)boolValue;
#endif
/*!
@method			stringWithBool:
@updated		March 2001
*/
+ (NSString *)stringWithBool:(BOOL)boolean;
@end

#pragma mark -
#import <AppKit/AppKit.h>

#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
/*
@interface NSMatrix (NGSSelectionIndicies)
- (NSIndexSet *)selectedRows;
- (NSIndexSet *)selectedColumns;
@end
*/
#endif

@interface NSOutlineView (NGSSelectedItemExtensions)
/*!
@method			selectedItem
@updated		September 2001
*/
- (id)selectedItem;
/*!
@method			selectedItems
@updated		September 2001
*/
- (NSArray *)selectedItems;
@end

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5

@interface NSGradient (NGSGradientExtensions)
/*!
@method			aquaGradient
@method			aquaGradientWithAlpha:
@method			gradientWithAlpha:
@updated		May 2007
*/
+ (NSGradient *)aquaGradient;
+ (NSGradient *)aquaGradientWithAlpha:(CGFloat)alpha;
- (NSGradient *)gradientWithAlpha:(CGFloat)alpha;
@end

#endif

#pragma mark -
#import <OpenGL/OpenGL.h>

@interface NSOpenGLContext (CGLContextAccess)
- (CGLContextObj)cglContext;
@end