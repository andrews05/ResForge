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
	
	[self readTemplate:va_arg( resourceList, id )];	// reads (but doesn't retain) the template for this resource (TMPL resource with name equal to the passed resource's type)
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
	[self readData];
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
			[tmpl addObject:[Element elementOfType:type withLabel:label]];
		}
	}
}

- (void)readData
{
	// tmpl == array of Elements describing the template for this resource
	// res == array of either Elements or Arrays containing the resource data
	
	// this function creates the res instance variable, filling it with data from the resource if there's data available.
	
	unsigned long position = 0;							// position (byte offset) in resource I'm currently reading from
	char *data = (char *) [[resource data] bytes];		// address of initial byte of resource in memory
	
	unsigned long templateCounter = 0;										// index into template array of the current template element
	Element *currentTemplateElement;										// current template element
	NSMutableArray *targetStack = [NSMutableArray arrayWithObject:res];		// stack of arrays (target for addition of new elements)
	NSMutableArray *loopStack = [NSMutableArray array];						// stack for 'LSTB' and 'LSTC' elements
	NSMutableArray *loopCountStack = [NSMutableArray array];				// stack for counting how many times to loop
	
	// when templateCounter >= [tmpl count], loop is only exited if targetStack has more than one target (this handles empty templates)
	while( templateCounter < [tmpl count] || [targetStack count] > 1 )
	{
		currentTemplateElement = [tmpl objectAtIndex:templateCounter];
		NSLog( @"template = %@", currentTemplateElement );
/*		unsigned long type = [currentTemplateElement typeAsLong];
		switch( type )
		{
			case 'BCNT':
			case 'BZCT':
				[resourceElement setNumberWithLong:*(unsigned char *)(data + position)];
				lim = *(unsigned char *)(data + position) + (type == 'BZCT'? 1:0);
				position += 1;
				break;
			case 'OCNT':
			case 'ZCNT':
				[resourceElement setNumberWithLong:*(unsigned short *)(data + position)];
				lim = *(unsigned short *)(data + position) + (type == 'ZCNT'? 1:0);
				position += 2;
				break;
			case 'LCNT':
			case 'LZCT':
				[resourceElement setNumberWithLong:*(unsigned long *)(data + position)];
				lim = *(unsigned long *)(data + position) + (type == 'LZCT'? 1:0);
				position += 4;
				break;
			
			case 'LSTB':
			case 'LSTC':
				[(NSMutableArray *)[targetStack lastObject] addObject:[NSMutableArray array]];
				[loopStack addObject:currentTemplateElement];	// append the template loop start object to the array
				break;
			
			default:
				
//				[(NSMutableArray *)[targetStack lastObject] addItem:[self createElementForTemplate:currentTemplateElement
		}
*/		
		templateCounter++;
	}
}

- (void)parseData
{
	unsigned long position = 0;
	char *data = (char *) [[resource data] bytes];
	
	// used for nesting of elements, 'target' is current object to append to, targetStack is a FILO stack of mutable array pointers, loopStack is a stack of element indicies to the start of loops, so I can go back to the head of a loop when iterating it
	NSMutableArray *target = res;
	NSMutableArray *targetStack = [NSMutableArray arrayWithObject:res];
	NSMutableArray *loopStack = [NSMutableArray array];
	
	// n = current item in TMPL to read, c = loop counter, when exiting loop, go back 'c' items in the template, lim is how many times to loop, obtained from a loop count
	unsigned long n = 0, c = 0, lim = 0;
	
	// creates an array of elements containing the data in whatever format the template dictates
	//	array can then simply be manipulated one element at a time, or flattened to save
	Element *currentTemplateElement, *resourceElement;
//	NSEnumerator *enumerator = [tmpl objectEnumerator];
//	while( currentTemplateElement = [enumerator nextObject] )
	while( position < [[resource size] unsignedLongValue] )
	{
		unsigned long type;
		
		currentTemplateElement = [tmpl objectAtIndex:n];
		n++, c++;
		type = [currentTemplateElement typeAsLong];
		resourceElement = [[currentTemplateElement copy] autorelease];
		NSLog( @"tmpl element = %@; position = %d", currentTemplateElement, position );
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
				[resourceElement setNumberWithLong:*(short *)(data + position)];
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
			case 'HEXD':
				// bug: doesn't check HEXD is the last element
				[resourceElement setData:[NSData dataWithBytes:(void *)(data + position) length:([[resource size] intValue] - position)]];
				position = [[resource size] intValue];
				break;
				
			/* Strings */
			case 'CHAR':
				[resourceElement setString:[[NSString alloc] initWithData:[NSData dataWithBytes:(void *)(data + position) length:1] encoding:NSMacOSRomanStringEncoding]];
				position += 1;
				break;
			case 'TNAM':
				[resourceElement setString:[[NSString alloc] initWithData:[NSData dataWithBytes:(void *)(data + position) length:4] encoding:NSMacOSRomanStringEncoding]];
				position += 4;
				break;
			case 'PSTR':
				[resourceElement setString:[[NSString alloc] initWithData:[NSData dataWithBytes:(void *)(data + position + 1) length:*(unsigned char *)(data + position)] encoding:NSMacOSRomanStringEncoding]];
				position += *(unsigned char *)(data + position) + 1;
				break;
			
			/* List Counts */
			case 'BCNT':
			case 'BZCT':
				// bug: how big are these various count fields?
				[resourceElement setNumberWithLong:*(unsigned char *)(data + position)];
				lim = *(unsigned char *)(data + position) + (type == 'BZCT'? 1:0);
				position += 1;
				break;
			case 'OCNT':
			case 'ZCNT':
				// bug: how big are these various count fields?
				[resourceElement setNumberWithLong:*(unsigned short *)(data + position)];
				lim = *(unsigned short *)(data + position) + (type == 'ZCNT'? 1:0);
				position += 2;
				break;
			case 'LCNT':
			case 'LZCT':
				// bug: how big are these various count fields?
				[resourceElement setNumberWithLong:*(unsigned long *)(data + position)];
				lim = *(unsigned long *)(data + position) + (type == 'LZCT'? 1:0);
				position += 4;
				break;
				
			/* List beginning and end */
			case 'LSTB':
			case 'LSTC':
				[target addObject:resourceElement];			// add list item to current target array
//				target = [resourceElement subelements];		// change current array to list's sub-elements
				[targetStack addObject:target];				// append sub-element array to target stack so it can be popped off afterwards
				resourceElement = nil;						// don't add item to it's own sub-elements later!
				break;
			case 'LSTE':
				// bug: if there is a LSTE without a preceeding LSTB or LSTC this will crash
				[targetStack removeLastObject];				// pop off current target from stack
				target = [targetStack lastObject];			// set current target to whatever was second from top on the stack
				resourceElement = nil;						// list end items are not needed in a resource array
				if( n < lim ) n -= c;
				c = 0;
				break;
			
			/* Cxxx, Hxxx or P0xx */
			default:
			// bug: should look for Cxxx, Hxxx or P0xx and complain if it's something else (an unknown type)!!
			{/*	long lengthStr = (type & 0x00FFFFFF) << 8;
				unsigned long length = strtoul( (char *) &lengthStr, nil, 10 );
			*/	char *lengthStr = (type & 0x00FFFFFF) & (3 << 24);
				unsigned long length;
				StringToNum(lengthStr, &length);
				NSLog( @"error, '%@' is unsupported, skipping %d bytes", [resourceElement type], length );
				resourceElement = nil;		// relies on element being previously autoreleased to avoid a leak
				position += length;
			}	break;
		}	// end template element type switch
		
		if( resourceElement )
		{
			NSLog( @"adding %@", resourceElement );
			[target addObject:resourceElement];
		}
	}	// end while position < size
	
	NSLog( [target description] );
}

- (void)createUI
{
	// iterate through res (the resource element array) creating fields
	[self enumerateElements:res];
}

- (void)enumerateElements:(NSMutableArray *)elements
{
	// iterate through the array of resource elements, creating fields
	Element *currentResourceElement;
	NSEnumerator *enumerator = [elements objectEnumerator];
	NSLog( @"elements in resource array = %d", [elements count] );
	while( currentResourceElement = [enumerator nextObject] )
	{
		// if element is a container (subelements != nil), iterate inside it first
/*		if( [currentResourceElement subelements] )
		{
			// bug: need to indent view right
			[self enumerateElements:[currentResourceElement subelements]];
			// bug: need to remove indentation
		}
		else	// element is normal
*/		{
		/*	NSFormCell *newField = [[NSFormCell alloc] initTextCell:[currentResourceElement label]];
			[fieldsMatrix addRowWithCells:[NSArray arrayWithObject:[newField autorelease]]];	*/
			NSLog( [currentResourceElement description] );
		}
	}
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
		[self refreshData:[resource data]];
}

- (void)refreshData:(NSData *)data;
{
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
