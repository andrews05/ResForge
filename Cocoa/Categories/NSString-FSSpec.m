#import "NSString-FSSpec.h"

@implementation NSString (ResKnifeFSSpecExtensions)

- (FSRef *)createFSRef
{
	// caller is responsible for disposing of the FSRef (method is a 'create' method)
	FSRef *fsRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	OSStatus error = FSPathMakeRef((unsigned char *)[self fileSystemRepresentation], fsRef, NULL);
	if(error == noErr)
		return fsRef;
	return NULL;
}

- (FSSpec *)createFSSpec
{
	// caller is responsible for disposing of the FSSpec (method is a 'create' method)
	FSRef *fsRef = (FSRef *) NewPtrClear(sizeof(FSRef));
	FSSpec *fsSpec = (FSSpec *) NewPtrClear(sizeof(FSSpec));
	OSStatus error = FSPathMakeRef((unsigned char *)[self fileSystemRepresentation], fsRef, NULL);
	if(error == noErr)
	{
		error = FSGetCatalogInfo(fsRef, kFSCatInfoNone, NULL, NULL, fsSpec, NULL);
		if(error == noErr)
		{
			DisposePtr((Ptr) fsRef);
			return fsSpec;
		}
	}
	DisposePtr((Ptr) fsRef);
	return NULL;
}

@end

@implementation NSString (ResKnifeBooleanExtensions)

- (BOOL)boolValue
{
	return ![self isEqualToString:@"NO"];
//	return [self isEqualToString:@"YES"];
}

+ (NSString *)stringWithBool:(BOOL)boolean
{
	return boolean? @"YES" : @"NO";
}

@end
