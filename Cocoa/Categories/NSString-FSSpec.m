#import "NSString-FSSpec.h"

@implementation NSString (ResKnifeFSSpecExtensions)

- (FSRef *)createFSRef
{
	FSRef *fsRef = NULL;
	OSStatus error = FSPathMakeRef( [self fileSystemRepresentation], &fsRef, NULL );
	if( error == noErr )
		return fsRef;
	return NULL;
}

- (FSSpec *)createFSSpec
{
	FSRef *fsRef = NULL;
	FSSpec *fsSpec = NULL;
	OSStatus error = FSPathMakeRef( [self fileSystemRepresentation], &fsRef, NULL );
	if( error == noErr )
	{
		error = FSGetCatalogInfo( &fsRef, kFSCatInfoNone, NULL, NULL, fsSpec, NULL );
		if( error == noErr )
			return fsSpec;
	}
	return NULL;
}

@end
