/* =============================================================================
	PROJECT:	ResKnife
	FILE:		ICONWindowController.h
	
	PURPOSE:	This is the main class of our bitmap resource editor. Every
				resource editor's main class implements the
				ResKnifePluginProtocol. Every editor should implement
				initWithResource:. Only implement initWithResources: if you feel
				like writing a template editor.
				
				Note that your plugin is responsible for committing suicide
				after its window has been closed. If you subclass it from
				NSWindowController, the controller will take care of that
				for you, according to a guy named Doug.
	
	AUTHORS:	M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Created.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import "ICONWindowController.h"



@implementation ICONWindowController


/* -----------------------------------------------------------------------------
	initWithResource:
		This is it! This is the constructor. Create your window here and
		do whatever else makes you happy. A new instance is created for each
		resource. Note that you are responsible for keeping track of your
		resource.
   -------------------------------------------------------------------------- */

-(id)   initWithResource: (id)newResource
{
	self = [self initWithWindowNibName:@"ICONWindow"];
	if( !self ) return nil;
	
	resource = [newResource retain];
	resData = nil;
	resImage = nil;
	
	// load the window from the nib
	[self window];
	return self;
}


/* -----------------------------------------------------------------------------
	* DESTRUCTOR
   -------------------------------------------------------------------------- */

-(void) dealloc
{
	[resImage autorelease];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[resData release];
	[super dealloc];
}


/* -----------------------------------------------------------------------------
	reloadResData:
		Loads the resource's data into our NSImageView.
   -------------------------------------------------------------------------- */

-(void) reloadResData
{
	unsigned char*			planes[2] = { 0, 0 };
	NSBitmapImageRep*		bir;
	NSString*				resType = [resource type];
	
	[resImage autorelease];
	resImage = [[NSImage alloc] init];
	
	resData = [[resource data] retain];
	planes[0] = (unsigned char*) [resData bytes];
	
	if( [resType isEqualToString: @"ICN#"] )
	{
		planes[1] = planes[0] + (4 * 32);   // 32 lines a 4 bytes.
		bir = [[[NSBitmapImageRep alloc] autorelease] initWithBitmapDataPlanes:planes pixelsWide:32 pixelsHigh:32
				bitsPerSample:1 samplesPerPixel:2 hasAlpha:YES isPlanar:YES colorSpaceName:NSCalibratedBlackColorSpace
				bytesPerRow:4 bitsPerPixel:1];
	}
	else if( [resType isEqualToString: @"ics#"] || [resType isEqualToString: @"CURS"] )
	{
		planes[1] = planes[0] + (2 * 16);   // 16 lines a 2 bytes.
		bir = [[[NSBitmapImageRep alloc] autorelease] initWithBitmapDataPlanes:planes pixelsWide:16 pixelsHigh:16
				bitsPerSample:1 samplesPerPixel:2 hasAlpha:YES isPlanar:YES colorSpaceName:NSCalibratedBlackColorSpace
				bytesPerRow:2 bitsPerPixel:1];
	}
	else if( [resType isEqualToString: @"icm#"] )
	{
		planes[1] = planes[0] + (2 * 12);   // 12 lines a 2 bytes.
		bir = [[[NSBitmapImageRep alloc] autorelease] initWithBitmapDataPlanes:planes pixelsWide:16 pixelsHigh:12
				bitsPerSample:1 samplesPerPixel:2 hasAlpha:YES isPlanar:YES colorSpaceName:NSCalibratedBlackColorSpace
				bytesPerRow:2 bitsPerPixel:1];
	}
	else
		bir = [[[NSBitmapImageRep alloc] autorelease] initWithBitmapDataPlanes:planes pixelsWide:32 pixelsHigh:32
				bitsPerSample:1 samplesPerPixel:1 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedBlackColorSpace
				bytesPerRow:4 bitsPerPixel:1]; 
	
	[resImage addRepresentation:bir];
	[imageView setImage: resImage];
	
	//[[self window] setContentSize:[resImage size]];
}


/* -----------------------------------------------------------------------------
	windowDidLoad:
		Our window is there, stuff the image in it.
   -------------------------------------------------------------------------- */

-(void) windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
	[[self window] setTitle:[resource defaultWindowTitle]];
	
	[self reloadResData];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}


/* -----------------------------------------------------------------------------
	resourceDataDidChange:
		Notification that someone changed our resource's data and we should
		update our display.
   -------------------------------------------------------------------------- */

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
	{
		[self reloadResData];
	}
}


/* -----------------------------------------------------------------------------
	imageViewChanged:
		The user changed our image view. Convert the image data to the proper
		format and stash it in our resource.
   -------------------------------------------------------------------------- */

-(IBAction)		imageViewChanged: (id)sender
{
	NSArray*	reps = [resImage representations];
	
	NSLog( @"# %d", [reps count] );
	
	[resImage lockFocusOnRepresentation: [reps objectAtIndex:0]];
	[[imageView image] dissolveToPoint: NSMakePoint(0,0) fraction:1];
	[resImage unlockFocus];
	
	[imageView setImage: resImage];
}

@end
