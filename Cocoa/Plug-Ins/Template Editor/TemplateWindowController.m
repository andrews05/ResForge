#import "TemplateWindowController.h"
#import "Element.h"
#import <stdarg.h>

@implementation TemplateWindowController

NSString *ResourceWillChangeNotification			= @"ResourceWillChangeNotification";
NSString *ResourceNameWillChangeNotification		= @"ResourceNameWillChangeNotification";
NSString *ResourceTypeWillChangeNotification		= @"ResourceTypeWillChangeNotification";
NSString *ResourceIDWillChangeNotification			= @"ResourceIDWillChangeNotification";
NSString *ResourceAttributesWillChangeNotification	= @"ResourceAttributesWillChangeNotification";
NSString *ResourceDataWillChangeNotification		= @"ResourceDataWillChangeNotification";

NSString *ResourceNameDidChangeNotification			= @"ResourceNameDidChangeNotification";
NSString *ResourceTypeDidChangeNotification			= @"ResourceTypeDidChangeNotification";
NSString *ResourceIDDidChangeNotification			= @"ResourceIDDidChangeNotification";
NSString *ResourceAttributesDidChangeNotification	= @"ResourceAttributesDidChangeNotification";
NSString *ResourceDataDidChangeNotification			= @"ResourceDataDidChangeNotification";
NSString *ResourceDidChangeNotification				= @"ResourceDidChangeNotification";

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"TemplateWindow"];
	if( !self ) return self;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	resource = [newResource retain];
	tmpl = [[NSMutableArray alloc] init];
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( ![[resource name] isEqualToString:@""] )
		[[self window] setTitle:[resource name]];
//	else leave name as set in nib file
	return self;
}

- (id)initWithResources:(id)newResource, ...
{
	va_list resourceList;
	va_start( resourceList, newResource );
	self = [self initWithResource:newResource];
	if( self )
	{
		id currentResource;
		[self readTemplate:va_arg( resourceList, id )];	// reads (but doesn't retain) the TMPL resource
		while( currentResource = va_arg( resourceList, id ) )
		{
			NSLog( @"too many params passed to -initWithResources: %@", [currentResource description] );
		}
	}
	va_end( resourceList );
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[tmpl autorelease];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// parse data using pre-scanned template and create the fields as needed
	[self parseData];
	[self createUI];
	
	// insert the resources' data into the text fields
	[self refreshData:[resource data]];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (void)readTemplate:(id <ResKnifeResourceProtocol>)tmplResource
{
	if( !tmplResource ) NSLog( @"resource template was invalid" );
	else
	{
		NSString *label, *type;
		char *currentByte = [[tmplResource data] bytes];
		unsigned long size = [[tmplResource data] length], position = 0;
		while( position < size )
		{
			// save where pointer will be AFTER having loaded this element
			position += *currentByte +5;
			
			// obtain label and type
			label = [NSString stringWithCString:currentByte +1 length:*currentByte];
			currentByte += *currentByte +1;
			type = [NSString stringWithCString:currentByte length:4];
			currentByte += 4;
			
			// add element to array
			[tmpl addObject:[Element elementOfType:type withLabel:label]];
		}
	}
}

- (void)parseData
{

}

- (void)createUI
{
	NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[NSWindow contentRectForFrameRect:[[[self window] contentView] frame] styleMask:0]];
	[[[self window] contentView] addSubview:scrollView];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for other resource notifications)
	if( [notification object] == (id)resource )
		[self refreshData:[resource data]];
}

- (void)refreshData:(NSData *)data;
{
#warning Should update data when datachanged notification received
}

- (id)resource
{
	return resource;
}

- (NSData *)data
{
	return [resource data];
}

@end
