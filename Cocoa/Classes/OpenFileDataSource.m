#import "OpenFileDataSource.h"
#import <unistd.h>
#import <sys/attr.h>

struct directoryinfo {
   unsigned long length;
   u_int32_t dirid;
};

struct dunnowhat
{
	unsigned long length;
	u_int32_t data1;
	u_int32_t data2;
	u_int32_t data3;
	u_int32_t data4;
	u_int32_t data5;
	u_int32_t data6;
};

@implementation OpenFileDataSource

//get action method and target of browser, intercept (or re-route and call it myself)

/* NSTableView data source protocol implementation */
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	NSBrowser *browser = [(NSOpenPanel *)[tableView window] browser];
	if( [[browser selectedCells] count] == 1 )
	{
		// only one file is selected, parse it for forks
/*		const char *path = [[browser path] cString];
		struct attrlist attributes;
		struct directoryinfo fileinfo;
		
		NSLog( @"%s", path );
//		memset( &attributes, 0, sizeof(struct attrlist) );
		bzero( &attributes, sizeof(struct attrlist) );
		attributes.bitmapcount = ATTR_BIT_MAP_COUNT;
//		attributes.fileattr = ATTR_FILE_FORKCOUNT;
		attributes.commonattr = ATTR_CMN_OBJID;
		int result = getattrlist( path, &attributes, &fileinfo, sizeof(struct directoryinfo), 0 );
		NSLog( @"%d", result );
		if( result != 0 ) return 0;
		NSLog( @"%d", fileinfo.length );
		NSLog( @"%d", fileinfo.dirid );
*/		
		struct attrlist alist;
		struct directoryinfo dirinfo;
		char *path = [[browser path] cString];
		bzero(&alist, sizeof(alist));
		alist.bitmapcount = 5;
		alist.commonattr = ATTR_CMN_OBJID;
		int result = getattrlist(path, &alist, &dirinfo, sizeof(dirinfo), 0);
		printf("result: %d; directory id: %lu; %s\n", result, dirinfo.dirid, path);

		return 3;
	}
	
	// multiple/no selected files, return nothing
	else return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	;
}

/*
		NSLog( [browser path] );
		CatPositionRec forkIterator;
		forkIterator.initialize = 0;
		FSIterateForks( FSRef *ref, &forkIterator, NULL, NULL, NULL );
*/

@end

@implementation OpenPanelDelegate

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
/*	NSMethodSignature *sig;
	NS_DURING
		sig = [super methodSignatureForSelector:selector];
	NS_HANDLER
		sig = [originalDelegate methodSignatureForSelector:selector];
	NS_ENDHANDLER
	return sig;	*/
	return [originalDelegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	if( [originalDelegate respondsToSelector:[invocation selector]] )
		[invocation invokeWithTarget:originalDelegate];
	else [self doesNotRecognizeSelector:[invocation selector]];
}

@end

@implementation NSSavePanel (ResKnife)

- (NSBrowser *)browser
{
	return _browser;
}

@end