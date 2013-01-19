#import "NGSCategories.h"

@implementation NSArray (NGSIndexExtensions)
- (NSArray *)subarrayWithIndicies:(NSIndexSet *)indicies
{
	NSRange range = {0,[self count]};
	NSUInteger count = [indicies count];
	NSUInteger *buffer = (NSUInteger *)calloc(count, sizeof(NSUInteger));
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:count];
	[indicies getIndexes:buffer maxCount:count inIndexRange:&range];
	for(unsigned int i = 0; i < count; i++)
		[newArray addObject:[self objectAtIndex:*(buffer+i)]];

	free(buffer);
	
	return [NSArray arrayWithArray:newArray];
}
@end

@implementation NSArray (NGSKeyValueExtensions)
- (int)indexOfFirstObjectReturningValue:(id)value forKey:(id)key
{
	return [[self valueForKey:key] indexOfObject:value];
}
- (id)firstObjectReturningValue:(id)value forKey:(id)key
{
	NSUInteger index = [[self valueForKey:key] indexOfObject:value];
	if(index != NSNotFound)
		return [self objectAtIndex:index];
	else return nil;
}
- (NSArray *)objectsReturningValue:(id)value forKey:(id)key
{
	id object;
	NSMutableArray *array = [NSMutableArray array];
	NSEnumerator *enumerator = [self objectEnumerator];
	while(object = [enumerator nextObject])
		if([[object valueForKey:key] isEqual:value])
			[array addObject:object];
	return [NSArray arrayWithArray:array];
}
- (NSArray *)arrayByMakingObjectsPerformSelector:(SEL)selector withObject:(id)inObject
{
	id object;
	NSMutableArray *array = [NSMutableArray array];
	NSEnumerator *enumerator = [self objectEnumerator];
	while(object = [enumerator nextObject])
		[array addObject:[object performSelector:selector withObject:inObject]];
	return [NSArray arrayWithArray:array];
}
@end

#pragma mark -

@implementation NSCharacterSet (NGSCharacterSetExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
+ (NSCharacterSet *)newlineCharacterSet
{
	unsigned char bitmapRep[8192];
	bitmapRep[0x0A >> 3] |= (((unsigned int)1) << (0x0A & 7));
	bitmapRep[0x0B >> 3] |= (((unsigned int)1) << (0x0B & 7));
	bitmapRep[0x0C >> 3] |= (((unsigned int)1) << (0x0C & 7));
	bitmapRep[0x0D >> 3] |= (((unsigned int)1) << (0x0D & 7));
	bitmapRep[0x85 >> 3] |= (((unsigned int)1) << (0x85 & 7));
	NSData *data = [NSData dataWithBytesNoCopy:bitmapRep length:8192 freeWhenDone:YES];
	return [NSCharacterSet characterSetWithBitmapRepresentation:data];
}
#endif
+ (NSCharacterSet *)tabCharacterSet
{
	unsigned char bitmapRep[8192] = { 0 };
	bitmapRep[0x09 >> 3] |= (((unsigned int)1) << (0x09 & 7));
	bitmapRep[0x0B >> 3] |= (((unsigned int)1) << (0x0B & 7));
	NSData *data = [NSData dataWithBytesNoCopy:bitmapRep length:8192 freeWhenDone:YES];
	return [NSCharacterSet characterSetWithBitmapRepresentation:data];
}
@end

#pragma mark -

@implementation NSIndexSet (NGSIndicies)
+ (id)indexSetWithIndiciesInRange:(NSRange)range
{	return [NSIndexSet indexSetWithIndexesInRange:range]; }
- (id)initWithIndiciesInRange:(NSRange)range
{	return [self initWithIndexesInRange:range]; }
- (NSUInteger)getIndicies:(NSUInteger *)indexBuffer maxCount:(NSUInteger)bufferSize inIndexRange:(NSRangePointer)range
{	return [self getIndexes:indexBuffer maxCount:bufferSize inIndexRange:range]; }
- (BOOL)containsIndiciesInRange:(NSRange)range
{	return [self containsIndexesInRange:range]; }
- (BOOL)containsIndicies:(NSIndexSet *)indexSet
{	return [self containsIndexes:indexSet]; }
- (BOOL)intersectsIndiciesInRange:(NSRange)range
{	return [self intersectsIndexesInRange:range]; }
@end

@implementation NSMutableIndexSet (NGSIndicies)
- (void)addIndicies:(NSIndexSet *)indexSet
{	[self addIndexes:indexSet]; }
- (void)removeIndicies:(NSIndexSet *)indexSet
{	[self removeIndexes:indexSet]; }
- (void)removeAllIndicies
{	[self removeAllIndexes]; }
- (void)addIndiciesInRange:(NSRange)range
{	[self addIndexesInRange:range]; }
- (void)removeIndiciesInRange:(NSRange)range
{	[self removeIndexesInRange:range]; }
- (void)shiftIndiciesStartingAtIndex:(unsigned int)index by:(int)delta
{	[self shiftIndexesStartingAtIndex:index by:delta]; }   
@end

#pragma mark -

@implementation NSNumber (NGSRangeExtensions)
- (BOOL)isWithinRange:(NSRange)range				// location <= self <= location+length
{
	// e.g. for {6,1} a value of 6.000 will return true, as will 7.000
	return [self compare:[NSNumber numberWithInt:range.location]] != NSOrderedAscending && [self compare:[NSNumber numberWithInt:range.location+range.length]] != NSOrderedDescending;
}
- (BOOL)isExclusivelyWithinRange:(NSRange)range		// location < self < location+length
{
	// e.g. for {6,1} a value of 6.000 will return false, 6.001 will return true, 6.999 will return true, 7.000 false
	return [self compare:[NSNumber numberWithInt:range.location]] == NSOrderedDescending && [self compare:[NSNumber numberWithInt:range.location+range.length]] == NSOrderedAscending;
}
- (BOOL)isBoundedByRange:(NSRange)range				// location <= self < location+length
{
	// e.g. for {6,1} a value of 6.000 will return true, 6.999 will return true, 7.000 will not
	return [self compare:[NSNumber numberWithInt:range.location]] != NSOrderedAscending && [self compare:[NSNumber numberWithInt:range.location+range.length]] == NSOrderedAscending;
}
@end

#pragma mark -

@implementation NSString (NGSFSSpecExtensions)
- (FSRef *)createFSRef
{
	// caller is responsible for disposing of the FSRef (method is a 'create' method)
	FSRef *fsRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	OSStatus error = FSPathMakeRef((const UInt8 *)[self fileSystemRepresentation], fsRef, NULL);
	if(error != noErr) fsRef = NULL;
	return fsRef;
}
- (FSSpec *)createFSSpec
{
	// caller is responsible for disposing of the FSSpec (method is a 'create' method)
	FSRef *fsRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	FSSpec *fsSpec = (FSSpec *) NewPtrClear(sizeof(FSSpec));
	OSStatus error = FSPathMakeRef((const UInt8 *)[self fileSystemRepresentation], fsRef, NULL);
	if(error == noErr)
	{
		error = FSGetCatalogInfo(fsRef, kFSCatInfoNone, NULL, NULL, fsSpec, NULL);
		if(error == noErr)
		{
			DisposePtr((Ptr)fsRef);
			return fsSpec;
		}
	}
	DisposePtr((Ptr)fsRef);
	DisposePtr((Ptr)fsSpec);
	return NULL;
}
@end

@implementation NSString (NGSBooleanExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
- (BOOL)boolValue
{
	return ![self isEqualToString:@"NO"];
}
#endif
+ (NSString *)stringWithBool:(BOOL)boolean
{
	return boolean? @"YES" : @"NO";
}
@end

#pragma mark -

#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
/*
@implementation NSMatrix (NGSSelectionIndicies)
- (NSIndexSet *)selectedRows
{
	int numRows, numCols;
	NSMutableIndexSet *rows = [[NSMutableIndexSet alloc] init];
	[self getNumberOfRows:&numRows columns:&numCols];
	for(int r = 0; r < numRows; r++)
	{
		for(int c = 0; c < numCols; c++)
		{
			if()
			{
				c = numCols;
				continue;
			}
		}
	}
}
- (NSIndexSet *)selectedColumns
{
	NSMutableIndexSet *columns = [[NSMutableIndexSet alloc] init];
}
@end
*/
#endif

@implementation NSOutlineView (NGSSelectedItemExtensions)
- (id)selectedItem
{
	if([self numberOfSelectedRows] != 1) return nil;
	else return [self itemAtRow:[self selectedRow]];
}
- (NSArray *)selectedItems;
{
	NSMutableArray *items = [NSMutableArray array];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_3
	NSIndexSet *indicies = [self selectedRowIndexes];
    NSUInteger rowIndex = [indicies firstIndex];
    while (rowIndex != NSNotFound)
	{
        [items addObject:[self itemAtRow:rowIndex]];
        rowIndex = [indicies indexGreaterThanIndex:rowIndex];
    }
#else
	NSNumber *row;
	NSEnumerator *enumerator = [self selectedRowEnumerator];
	while(row = [enumerator nextObject])
		[items addObject:[self itemAtRow:[row intValue]]];
#endif
	return items;
}
@end

#pragma mark -

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5

@implementation NSGradient (NGSGradientExtensions)
+ (NSGradient *)aquaGradient
{
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
		[NSColor colorWithCalibratedWhite: 0.95 alpha: 1.0], 0.0,
		[NSColor colorWithCalibratedWhite: 0.83 alpha: 1.0], 0.5,
		[NSColor colorWithCalibratedWhite: 0.95 alpha: 1.0], 0.5,
		[NSColor colorWithCalibratedWhite: 0.92 alpha: 1.0], 1.0, nil];
	return [gradient autorelease];
}
+ (NSGradient *)aquaGradientWithAlpha:(CGFloat)alpha
{
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
		[NSColor colorWithCalibratedWhite: 0.95 alpha: alpha], 0.0,
		[NSColor colorWithCalibratedWhite: 0.83 alpha: alpha], 0.5,
		[NSColor colorWithCalibratedWhite: 0.95 alpha: alpha], 0.5,
		[NSColor colorWithCalibratedWhite: 0.92 alpha: alpha], 1.0, nil];
	return [gradient autorelease];
}
- (NSGradient *)gradientWithAlpha:(CGFloat)alpha
{
	NSColor *colour;
	NSInteger stops = [self numberOfColorStops];
	NSMutableArray *colours = [NSMutableArray array];
	CGFloat *locations = (CGFloat *) calloc(sizeof(CGFloat), stops);
	for(NSInteger i = 0; i < stops; i++)
	{
		[self getColor: &colour location: &(locations[i]) atIndex: i];
		[colours addObject: [colour colorWithAlphaComponent: alpha]];
	}
	NSGradient *gradient = [[NSGradient alloc] initWithColors: colours atLocations: locations colorSpace: [self colorSpace]];

	free(locations);
	return [gradient autorelease];
}
@end

#endif

#pragma mark -

/* CGLContext access for pre-10.3 */
@implementation NSOpenGLContext (CGLContextAccess)
- (CGLContextObj)cglContext
{
#if !__LP64__
	if(NSAppKitVersionNumber < 700.0)
		return _contextAuxiliary;
	else
#endif
		return (CGLContextObj) [self CGLContextObj];
}
@end