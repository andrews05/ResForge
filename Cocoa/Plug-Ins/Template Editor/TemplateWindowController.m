#import "TemplateWindowController.h"
#import "Element.h"
#import <stdarg.h>

@implementation TemplateWindowController

- (id)initWithResource:(id)newResource
{
	return [self initWithResources:newResource, nil];
}

- (id)initWithResources:(id)newResource, ...
{
	id currentResource;
	va_list resourceList;
	va_start( resourceList, newResource );
	
	// one instance of your principal class will be created for every resource set the user wants to edit (similar to Windows apps)
	self = [self initWithWindowNibName:@"TemplateWindow"];
	if( !self )
	{
		va_end( resourceList );
		return self;
	}
	
	resource = [newResource retain];
	tmpl = [[NSMutableArray alloc] init];
	res = [[NSMutableArray alloc] init];
	
	[self readTemplate:va_arg( resourceList, id )];	// reads (but doesn't retain) the TMPL resource
	while( currentResource = va_arg( resourceList, id ) )
		NSLog( @"too many params passed to -initWithResources: %@", [currentResource description] );
	va_end( resourceList );
	
	// load the window from the nib
	[self window];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[tmpl autorelease];
	[res autorelease];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
	if( ![[resource name] isEqualToString:@""] )
		[[self window] setTitle:[resource name]];
	
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
		char *currentByte = (char *) [[tmplResource data] bytes];
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
//			NSLog( @"Adding object %@ of type %@ to array", label, type );
			[tmpl addObject:[Element elementOfType:type withLabel:label]];
		}
	}
}

- (void)parseData
{
	unsigned long position = 0, loopStart;
	char *data = (char *) [resource data];
	
	// creates an array of elements containing the data in whatever format the template dictates
	//	array can then simply be manipulated one element at a time, or flattened to save
	Element *currentTemplateElement, *resourceElement;
	NSEnumerator *enumerator = [tmpl objectEnumerator];
	while( currentTemplateElement = [enumerator nextObject] )
	{
		unsigned long type = [currentTemplateElement typeAsLong];
		resourceElement = [[currentTemplateElement copy] autorelease];
		switch( type )
		{
			/* Alignment */
			case 'AWRD':
				position += position % 2;
				break;
			case 'ALNG':
				position += position % 4;
				break;
			
			/* Fillers */
			case 'FBYT':
				position += 1;
				break;
			case 'FWRD':
				position += 2;
				break;
			case 'FLNG':
				position += 4;
				break;
			
			/* Decimal */
			case 'DBYT':
				[resourceElement setNumberWithLong:*(char *)(data + position)];
				position += 1;
				break;
			case 'DWRD':
				[resourceElement setNumberWithLong:*(int *)(data + position)];
				position += 2;
				break;
			case 'DLNG':
				[resourceElement setNumberWithLong:*(long *)(data + position)];
				position += 4;
				break;
			
			/* Hex */
			case 'HBYT':
				[resourceElement setData:[NSData dataWithBytes:(void *)(data + position) length:1]];
				position += 1;
				break;
			case 'HWRD':
				[resourceElement setData:[NSData dataWithBytes:(void *)(data + position) length:2]];
				position += 2;
				break;
			case 'HLNG':
				[resourceElement setData:[NSData dataWithBytes:(void *)(data + position) length:4]];
				position += 4;
				break;
			
			/* Cxxx, Hxxx or P0xx */
			default:
			{	unsigned long length = type & 0x00FFFFFF;
				NSLog( @"error, Cxxx, Hxxx and P0xx unsupported" );
				resourceElement = nil;		// relies on element being previously autoreleased to avoid a leak
			}	break;
		}	// end switch
		if( resourceElement )	[res addObject:resourceElement];
	}		// end while loop
}

- (void)createUI
{
	// iterate through res creating fields
	Element *currentResourceElement;
	NSEnumerator *enumerator = [res objectEnumerator];
	NSLog( @"%d", [res count] );
	while( currentResourceElement = [enumerator nextObject] )
	{
		NSFormCell *newField = [[NSFormCell alloc] initTextCell:[currentResourceElement label]];
		[fieldsMatrix addRowWithCells:[NSArray arrayWithObject:[newField autorelease]]];
		NSLog( @"%@ added to matrix", [newField description] );
	}
	NSLog( [fieldsMatrix description] );
	[fieldsMatrix setNeedsDisplay];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
		[self refreshData:[resource data]];
}

- (void)refreshData:(NSData *)data;
{
#warning Should update data when datachanged notification received
	// put data from resource into correct fields 
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
