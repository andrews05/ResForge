#import "NovaWindowController.h"
#import "BoomWindowController.h"
#import "CharWindowController.h"
#import "ColrWindowController.h"
#import "CronWindowController.h"
#import "DescWindowController.h"

@implementation NovaWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	id oldSelf = self;
	NSData *classData = [[(id <ResKnifeResourceProtocol>)newResource type] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *className = [[[NSString stringWithCString:[classData bytes] length:[classData length]] capitalizedString] stringByAppendingString:@"WindowController"];
	if( [className isEqualToString:@"Yea(R)WindowController"] ) className = @"YearWindowController";
	self = [[NSClassFromString(className) alloc] initWithResource:newResource];
	[oldSelf release];
	if( !self ) return nil;
	
	// do global stuff here
	resource = [(id)newResource retain];
	undoManager = [[NSUndoManager alloc] init];
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( [newResource name] && ![[newResource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", [[self window] title], [newResource name]]];
	return self;
}

- (id)initWithResources:(id <ResKnifeResourceProtocol>)newResource, ...
{
	return nil;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[undoManager release];
	[shipDataSource release];
	[super dealloc];
}

- (void)windowDidLoad
{
	NSBundle *plugBundle = [NSBundle bundleWithIdentifier:@"au.com.sutherland-studios.resknife.novatools"];
	
/*	NSLog( @"path: %@", [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"NovaTools"] );
	NSLog( @"path: %@", [[NSBundle mainBundle] pathForResource:@"NovaTools" ofType:nil] );
	NSLog( @"path: %@", [[NSBundle mainBundle] pathForResource:@"NovaTools" ofType:nil inDirectory:@"PlugIns"] );
	NSLog( @"path: %@", [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"NovaTools.plugin"] );
	NSLog( @"path: %@", [[NSBundle bundleWithIdentifier:@"au.com.sutherland-studios.resknife.novatools"] bundlePath] );
*/	
	[super windowDidLoad];
	
	// create the data sources (here because this is called just before they are applied to the combo boxes)
	governmentDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"govt" value:@"" table:@"Resource Types"]];
	planetDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"spob" value:@"" table:@"Resource Types"]];
	shipDataSource = [[DataSource alloc] initForType:[plugBundle localizedStringForKey:@"ship" value:@"" table:@"Resource Types"]];
	
	// we don't want this notification until we have a window!
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	// bug: only registers for notifications on the resource we're editing, need dependant resources too (pass nil for object?)
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

- (void)setResource:(id <ResKnifeResourceProtocol>)newResource
{
	id old = resource;
	resource = [(id)newResource retain];
	[old release];
}

- (void)setUndoManager:(NSUndoManager *)newUndoManager
{
	id old = undoManager;
	undoManager = [newUndoManager retain];
	[old release];
}

- (IBAction)toggleResID:(id)sender
{
	// toggles between resource IDs and index numbers
	NSLog( @"%@", [resource type] );
}

- (void)resourceNameDidChange:(NSNotification *)notification
{
	NSString *prefix;
	NSScanner *scanner = [NSScanner scannerWithString:[[self window] title]];
	if( ![scanner scanUpToString:@":" intoString:&prefix] )
		prefix = [[self window] title];
	if( ![[(id <ResKnifeResourceProtocol>)[notification object] name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", prefix, [(id <ResKnifeResourceProtocol>)[notification object] name]]];
	else [[self window] setTitle:prefix];
}

@end
