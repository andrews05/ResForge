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

-(void)reloadResData
{
	unsigned char*			planes[2] = { 0, 0 };
	NSBitmapImageRep*		bir;
	NSString*				resType = [resource type];
	
	[resImage autorelease];
	resImage = [[NSImage alloc] init];
	
	// -mutableCopy the data instead of retaining, so we don't get inverted pixels on reopening the resource
	// (since switching to NSCalibratedWhiteColorSpace)
	resData = [[resource data] mutableCopy];
	planes[0] = (unsigned char*) [resData bytes];
	NSUInteger plane0length = 0;
	NSUInteger pixelsWide = 32;
	NSUInteger pixelsHigh = 32;
	BOOL hasAlpha = YES;
	BOOL isPlanar = YES;
	NSUInteger bytesPerRow = 0;
	NSUInteger samplesPerPixel = 2;
	
	if( [resType isEqualToString: @"ICN#"] )
	{
		bytesPerRow = 4;
	}
	else if( [resType isEqualToString: @"ics#"] || [resType isEqualToString: @"CURS"] )
	{
		bytesPerRow = 2;
		pixelsWide = pixelsHigh = 16;
	}
	else if( [resType isEqualToString: @"icm#"] )
	{
		bytesPerRow = 2;
		pixelsWide = 16;
		pixelsHigh = 12;
	}
	else {
		bytesPerRow = 4;
		hasAlpha = NO;
		isPlanar = NO;
		samplesPerPixel = 1;
	}
	
	plane0length = bytesPerRow * pixelsHigh;
	
	if (isPlanar)
		planes[1] = planes[0] + plane0length;
	
	for (NSUInteger i = 0; i < plane0length; ++i)
		planes[0][i] ^= 0xff;
	
	bir = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes pixelsWide:pixelsWide pixelsHigh:pixelsHigh
												bitsPerSample:1 samplesPerPixel:samplesPerPixel hasAlpha:hasAlpha isPlanar:isPlanar colorSpaceName:NSCalibratedWhiteColorSpace
												  bytesPerRow:bytesPerRow bitsPerPixel:1] autorelease];

		
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
	
	NSLog( @"# %lu", [reps count] );
	
	[resImage lockFocusOnRepresentation: [reps objectAtIndex:0]];
	[[imageView image] dissolveToPoint: NSMakePoint(0,0) fraction:1];
	[resImage unlockFocus];
	
	[imageView setImage: resImage];
}

@end
