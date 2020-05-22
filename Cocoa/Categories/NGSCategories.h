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

@interface NSArray (NGSKeyValueExtensions)
/*!
@method			indexOfFirstObjectReturningValue:forKey:
@updated		January 2003
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning the index of the first one encountered which itself returned the value passed in, according to <tt>isEqual:</tt>, or returns <tt>NSNotFound</tt> if no object matched for the given key/value pair. Mostly useful just for increasing code readability, as the methd is only one line long, but one that's not easy to understand at first glance.
@updated		2005-02-23 NGS: Removed unnecessary code, <tt>indexOfObject:</tt> already returns <tt>NSNotFound</tt> for me.
*/
- (NSInteger)indexOfFirstObjectReturningValue:(nonnull id)value forKey:(nonnull id)key;
/*!
@method			firstObjectReturningValue:forKey:
@updated		January 2003
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning the first one encountered which itself returned the value passed in, according to <tt>isEqual:</tt>. Returns <tt>nil</tt> if no matching object is found.
@updated		2005-02-23 NGS: Removed message to <tt>indexOfFirstObjectReturningValue:forKey:</tt>, incorperated that method's code into this one.
*/
- (nullable id)firstObjectReturningValue:(nonnull id)value forKey:(nonnull id)key;
/*!
@method			objectsReturningValue:forKey:
@updated		January 2003
@abstract		Returns an array containing all objects in the receiver which have <tt>value</tt> set for key <tt>key</tt>.
@discussion		Calls <tt>valueForKey:</tt> on each object in the array, returning a new array containing all objects which themselves returned the value passed in, according to <tt>isEqual:</tt>. If no objects matched, this method returns an empty array.
*/
- (nonnull NSArray *)objectsReturningValue:(nonnull id)value forKey:(nonnull id)key;
@end
