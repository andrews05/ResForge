/* =============================================================================
	PROJECT:	ResKnife
	FILE:		NuTemplateWindowController.h
	
	PURPOSE:	This is the main class of our template editor. Every
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

#import "NuTemplateWindowController.h"
#import "NuTemplateElement.h"
#import "NuTemplateLSTBElement.h"
#import "NuTemplateLSTEElement.h"
#import "NuTemplateTNAMElement.h"
#import "NuTemplatePSTRElement.h"
#import "NuTemplateDWRDElement.h"
#import "NuTemplateDLNGElement.h"
#import "NuTemplateDBYTElement.h"
#import "NuTemplateOCNTElement.h"
#import "NuTemplateLSTCElement.h"
#import "NuTemplateStream.h"

#import "NSOutlineView-SelectedItems.h"


@implementation NuTemplateWindowController


/* -----------------------------------------------------------------------------
	initWithResource:
		This is it! This is the constructor. Create your window here and
		do whatever else makes you happy. A new instance is created for each
		resource. Note that you are responsible for keeping track of your
		resource.
   -------------------------------------------------------------------------- */

- (id)initWithResource:(id)newResource
{
	return [self initWithResources:newResource, nil];
}

- (id)initWithResources:(id)newResource, ...
{
	id			currentResource;
	va_list		resourceList;
	
	va_start( resourceList, newResource );
	
	self = [self initWithWindowNibName:@"NuTemplateWindow"];
	if( !self )
	{
		va_end( resourceList );
		return self;
	}
	
	createFieldItem = nil;
	resource = [newResource retain];
	templateStructure = [[NSMutableArray alloc] init];
	resourceStructure = [[NSMutableArray alloc] init];
	
	currentResource = va_arg( resourceList, id );
	[self readTemplate:currentResource];	// reads (but doesn't retain) the template for this resource (TMPL resource with name equal to the passed resource's type)
	
	while( currentResource = va_arg( resourceList, id ) )
		NSLog( @"too many params passed to -initWithResources: %@", [currentResource description] );
	va_end( resourceList );
	
	// load the window from the nib
	[self window];
	return self;
}


/* -----------------------------------------------------------------------------
	* DESTRUCTOR
   -------------------------------------------------------------------------- */

-(void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[templateStructure release];
	[resourceStructure release];
	
	[super dealloc];
}


/* -----------------------------------------------------------------------------
	windowDidLoad:
		Our window is there, stuff the image in it.
   -------------------------------------------------------------------------- */

-(void) windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
	[[self window] setTitle:[resource nameForEditorWindow]];
	
	[self reloadResData];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
	
	[displayList reloadData];
}


/* -----------------------------------------------------------------------------
	resourceDataDidChange:
		Notification that someone changed our resource's data and we should
		update our display.
   -------------------------------------------------------------------------- */

-(void)	resourceDataDidChange: (NSNotification*)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
		[self reloadResData];
}


-(void)	reloadResData
{
	char*					theData = (char*) [[resource data] bytes];
	unsigned long			bytesToGo = [[resource data] length];
	NuTemplateStream*		stream = [NuTemplateStream streamWithBytes: theData length: bytesToGo];
	NSEnumerator*			enny = [templateStructure objectEnumerator];
	NuTemplateElement*		currElement;
	
	[resourceStructure removeAllObjects];	// Get rid of old parsed resource.
	
	// Loop over template and read each field:
	while( currElement = [enny nextObject] )
	{
		currElement = [[currElement copy] autorelease];		// Copy the template object.
		
		if( [[currElement type] isEqualToString: @"OCNT"] )
			NSLog( @"Instantiated: %@", currElement );
		
		[resourceStructure addObject: currElement];		// Add it to our parsed resource data list. Do this right away so the element can append other items should it desire to.
		[currElement setContaining: resourceStructure];
		[currElement readDataFrom: stream];		// Fill it with resource data.
	}
	
	[dataList reloadData];	// Make sure our outline view displays the new data.
}


-(void)	writeResData
{
	unsigned int		theSize = 0;
	NSEnumerator*		enny = [resourceStructure objectEnumerator];
	NuTemplateElement*	obj;
	
	while( obj = [enny nextObject] )
		theSize += [obj sizeOnDisk];
	
	NSMutableData*		newData = [NSMutableData dataWithLength: theSize];
	NuTemplateStream*	stream = [NuTemplateStream streamWithBytes: [newData bytes] length: theSize];
	
	enny = [resourceStructure objectEnumerator];
	while( obj = [enny nextObject] )
		[obj writeDataTo: stream];
	
	[resource setData: newData];
}


-(void)	readTemplate: (id <ResKnifeResourceProtocol>)tmplRes
{
	char*					theData = (char*) [[tmplRes data] bytes];
	unsigned long			bytesToGo = [[tmplRes data] length];
	NuTemplateStream*		stream = [NuTemplateStream streamWithBytes: theData length: bytesToGo];
	NSMutableDictionary*	fieldReg = [NuTemplateStream fieldRegistry];
	
	// Registry empty? Add field types we support:
	if( [fieldReg count] == 0 )
	{
		[fieldReg setObject: [NuTemplateLSTBElement class] forKey: @"LSTB"];
		[fieldReg setObject: [NuTemplateLSTBElement class] forKey: @"LSTZ"];
		[fieldReg setObject: [NuTemplateLSTEElement class] forKey: @"LSTE"];
		[fieldReg setObject: [NuTemplateTNAMElement class] forKey: @"TNAM"];
		[fieldReg setObject: [NuTemplatePSTRElement class] forKey: @"PSTR"];
		[fieldReg setObject: [NuTemplatePSTRElement class] forKey: @"P100"];
		[fieldReg setObject: [NuTemplatePSTRElement class] forKey: @"P020"];
		[fieldReg setObject: [NuTemplatePSTRElement class] forKey: @"P040"];
		[fieldReg setObject: [NuTemplateDWRDElement class] forKey: @"DWRD"];
		[fieldReg setObject: [NuTemplateDLNGElement class] forKey: @"DLNG"];
		[fieldReg setObject: [NuTemplateDBYTElement class] forKey: @"DBYT"];
		[fieldReg setObject: [NuTemplateDBYTElement class] forKey: @"CHAR"];
		[fieldReg setObject: [NuTemplateOCNTElement class] forKey: @"OCNT"];
		[fieldReg setObject: [NuTemplateOCNTElement class] forKey: @"ZCNT"];
		[fieldReg setObject: [NuTemplateOCNTElement class] forKey: @"LCNT"];
		[fieldReg setObject: [NuTemplateOCNTElement class] forKey: @"LZCT"];
		[fieldReg setObject: [NuTemplateLSTCElement class] forKey: @"LSTC"];
	}
	
	// Read new fields from the template and add them to our list:
	while( [stream bytesToGo] > 0 )
	{
		NuTemplateElement*	obj = [stream readOneElement];
		
		[templateStructure addObject: obj];
	}
	
	[displayList reloadData];
}


-(id)	outlineView:(NSOutlineView*)outlineView child:(int)index ofItem:(id)item
{
	if( (item == nil) && (outlineView == displayList) )
		return [templateStructure objectAtIndex:index];
	else if( (item == nil) && (outlineView == dataList) )
		return [resourceStructure objectAtIndex:index];
	else
		return [item subElementAtIndex: index];
}


-(BOOL)	outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ([item subElementCount] > 0);
}

-(int)	outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if( (item == nil) && (outlineView == displayList) )
		return [templateStructure count];
	else if( (item == nil) && (outlineView == dataList) )
		return [resourceStructure count];
	else
		return [item subElementCount];
}

-(id)	outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [item valueForKey:[tableColumn identifier]];
}

-(void)	outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NS_DURING
		[item takeValue:object forKey: [tableColumn identifier]];
	NS_HANDLER
		
	NS_ENDHANDLER
}


-(IBAction)	cut: (id)sender;
{
	NuTemplateElement *selItem = (NuTemplateElement*) [dataList selectedItem];
	
	[selItem cut: sender];	// Let selected item do its magic.
	
	[dataList reloadData];	// Update our display.
}

-(IBAction)	copy: (id)sender;
{
	NuTemplateElement *selItem = (NuTemplateElement*) [dataList selectedItem];
	
	[selItem copy: sender];	// Let selected item do its magic.
	
	[dataList reloadData];	// Update our display.
}

-(IBAction)	paste: (id)sender;
{
	NuTemplateElement *selItem = (NuTemplateElement*) [dataList selectedItem];
	
	[selItem paste: sender];	// Let selected item do its magic.
	
	[dataList reloadData];	// Update our display.
}

-(IBAction)	clear: (id)sender;
{
	NuTemplateElement *selItem = (NuTemplateElement*) [dataList selectedItem];
	
	[selItem clear: sender];	// Let selected item do its magic.
	
	[dataList reloadData];	// Update our display.
}

/* showCreateResourceSheet: we mis-use this menu item for creating new template fields.
	This works by selecting an item that serves as a template (another LSTB), or knows
	how to create an item (LSTE) and passing the message on to it. */

-(IBAction)	showCreateResourceSheet: (id)sender;
{
	NuTemplateElement *selItem = (NuTemplateElement*) [dataList selectedItem];
	
	[selItem showCreateResourceSheet: sender];	// Let selected item do its magic.
	
	[dataList reloadData];	// Update our display.
}


-(BOOL)	validateMenuItem: (NSMenuItem*)item
{
	NuTemplateElement *selElement = (NuTemplateElement*) [dataList selectedItem];
	
	if( [item action] == @selector(showCreateResourceSheet:) )
	{
		createFieldItem = item;
		[item setTitle: NSLocalizedString(@"Create List Entry",@"")];
		
		return( selElement != nil && [selElement respondsToSelector: @selector(showCreateResourceSheet:)] );
	}
	else if( [item action] == @selector(cut:) )
		return( selElement != nil && [selElement respondsToSelector: @selector(cut:)] );
	else if( [item action] == @selector(copy:) )
		return( selElement != nil && [selElement respondsToSelector: @selector(copy:)] );
	else if( [item action] == @selector(paste:) && selElement != nil
			&& [selElement respondsToSelector: @selector(validateMenuItem:)] )
		return( [selElement validateMenuItem: item] );
	else if( [item action] == @selector(clear:) )
		return( selElement != nil && [selElement respondsToSelector: @selector(clear:)] );
	else if( [item action] == @selector(saveDocument:) )
		return YES;
	else return NO;
}


-(void)	windowDidResignKey: (NSNotification*)notification
{
	if( createFieldItem )
	{
		[createFieldItem setTitle: NSLocalizedString(@"Create New Resource...",@"")];
		createFieldItem = nil;
	}
}


-(IBAction)	saveDocument: (id)sender
{
	[self writeResData];
}


-(BOOL)	windowShouldClose: (id)sender	// Window delegate.
{
	[self writeResData];	// Save resource.

	return YES;
}

@end
