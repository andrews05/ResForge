#import "NGSCategories.h"

@implementation NSArray (NGSIndexExtensions)
- (NSArray *)subarrayWithIndicies:(NSIndexSet *)indicies
{
	NSRange range = NSMakeRange(0, [self count]);
	NSUInteger count = [indicies count];
	NSUInteger *buffer = (NSUInteger *)calloc(count, sizeof(NSUInteger));
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:count];
	[indicies getIndexes:buffer maxCount:count inIndexRange:&range];
	for(NSUInteger i = 0; i < count; i++)
		[newArray addObject:[self objectAtIndex:*(buffer+i)]];

	free(buffer);
	
	return [NSArray arrayWithArray:newArray];
}
@end

@implementation NSArray (NGSKeyValueExtensions)
- (NSInteger)indexOfFirstObjectReturningValue:(id)value forKey:(id)key
{
	return [[self valueForKey:key] indexOfObject:value];
}

- (id)firstObjectReturningValue:(id)value forKey:(id)key
{
	NSUInteger index = [[self valueForKey:key] indexOfObject:value];
	if(index != NSNotFound)
		return self[index];
	else
		return nil;
}

- (NSArray *)objectsReturningValue:(id)value forKey:(id)key
{
	NSMutableArray *array = [NSMutableArray array];
	for (id object in self) {
		if([[object valueForKey:key] isEqual:value]) {
			[array addObject:object];
		}
	}
	return [NSArray arrayWithArray:array];
}

- (NSArray *)arrayByMakingObjectsPerformSelector:(SEL)selector withObject:(id)inObject
{
	NSMutableArray *array = [NSMutableArray array];
	for (id object in self) {
		[array addObject:[object performSelector:selector withObject:inObject]];
	}
	return [NSArray arrayWithArray:array];
}
@end

#pragma mark -

@implementation NSCharacterSet (NGSCharacterSetExtensions)
+ (NSCharacterSet *)tabCharacterSet
{
	unsigned char bitmapRep[8192] = { 0 };
	bitmapRep[0x09 >> 3] |= (((unsigned int)1) << (0x09 & 7));
	bitmapRep[0x0B >> 3] |= (((unsigned int)1) << (0x0B & 7));
	NSData *data = [NSData dataWithBytesNoCopy:bitmapRep length:8192 freeWhenDone:NO];
	return [NSCharacterSet characterSetWithBitmapRepresentation:data];
}
@end

#pragma mark -

@implementation NSNumber (NGSRangeExtensions)
- (BOOL)isWithinRange:(NSRange)range				// location <= self <= location+length
{
	// e.g. for {6,1} a value of 6.000 will return true, as will 7.000
	return [self compare:@(range.location)] != NSOrderedAscending && [self compare:@(range.location+range.length)] != NSOrderedDescending;
}
- (BOOL)isExclusivelyWithinRange:(NSRange)range		// location < self < location+length
{
	// e.g. for {6,1} a value of 6.000 will return false, 6.001 will return true, 6.999 will return true, 7.000 false
	return [self compare:@(range.location)] == NSOrderedDescending && [self compare:@(range.location+range.length)] == NSOrderedAscending;
}
- (BOOL)isBoundedByRange:(NSRange)range				// location <= self < location+length
{
	// e.g. for {6,1} a value of 6.000 will return true, 6.999 will return true, 7.000 will not
	return [self compare:@(range.location)] != NSOrderedAscending && [self compare:@(range.location+range.length)] == NSOrderedAscending;
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
#ifdef __LP64__
	return NULL;
#else
	// caller is responsible for disposing of the FSSpec (method is a 'create' method)
	FSRef fsRef = {{0}};
	FSSpec *fsSpec = (FSSpec *)NewPtrClear(sizeof(FSSpec));
	OSStatus error = FSPathMakeRef((const UInt8 *)[self fileSystemRepresentation], &fsRef, NULL);
	if (error == noErr) {
		error = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, fsSpec, NULL);
		if(error == noErr) {
			return fsSpec;
		}
	}
	DisposePtr((Ptr)fsSpec);
	return NULL;
#endif
}
@end

@implementation NSString (NGSBooleanExtensions)
+ (NSString *)stringWithBool:(BOOL)boolean
{
	return boolean? @"YES" : @"NO";
}
@end

#pragma mark -

@implementation NSOutlineView (NGSSelectedItemExtensions)
- (id)selectedItem
{
	if([self numberOfSelectedRows] != 1) return nil;
	else return [self itemAtRow:[self selectedRow]];
}
- (NSArray *)selectedItems;
{
	NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indicies = [self selectedRowIndexes];
    NSUInteger rowIndex = [indicies firstIndex];
    while (rowIndex != NSNotFound) {
        [items addObject:[self itemAtRow:rowIndex]];
        rowIndex = [indicies indexGreaterThanIndex:rowIndex];
    }
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
	return gradient;
}

+ (NSGradient *)aquaGradientWithAlpha:(CGFloat)alpha
{
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
		[NSColor colorWithCalibratedWhite: 0.95 alpha: alpha], 0.0,
		[NSColor colorWithCalibratedWhite: 0.83 alpha: alpha], 0.5,
		[NSColor colorWithCalibratedWhite: 0.95 alpha: alpha], 0.5,
		[NSColor colorWithCalibratedWhite: 0.92 alpha: alpha], 1.0, nil];
	return gradient;
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
	return gradient;
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