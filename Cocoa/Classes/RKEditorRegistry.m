/* =============================================================================
	PROJECT:	ResKnife
	FILE:		RKEditorRegistry.m
	
	PURPOSE:
		This is a registry where all our resource-editor plugins are looked
		up and entered in a list, so you can ask for the editor for a specific
		resource type and it is returned immediately. This registry reads the
		types a plugin handles from their info.plist. This is better than
		encoding the type in the plugin file name, as file names are not
		guaranteed to be on a case-sensitive file system on Mac, and this also
		allows an editor to register for several resource types.
	
	AUTHORS:	M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Created.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import "RKEditorRegistry.h"


/* -----------------------------------------------------------------------------
	Globals:
   -------------------------------------------------------------------------- */

RKEditorRegistry*		gRKEditorRegistryMainRegistry = nil;	// Access through +mainRegistry!


@implementation RKEditorRegistry

/* -----------------------------------------------------------------------------
	mainRegistry:
		Returns the main plugin registry of this application, instantiating
		it first if there is none yet. As soon as this is instantiated, the
		plugins are loaded.
	
	REVISIONS:
		2003-07-31  UK  Created.
   -------------------------------------------------------------------------- */

+(RKEditorRegistry*)	mainRegistry
{
	if( !gRKEditorRegistryMainRegistry )
	{
		gRKEditorRegistryMainRegistry = [[RKEditorRegistry alloc] init];
		[gRKEditorRegistryMainRegistry scanForPlugins: gRKEditorRegistryMainRegistry];
	}
	return gRKEditorRegistryMainRegistry;
}


/* -----------------------------------------------------------------------------
	awakeFromNib:
		Makes sure that if an instance of this is instantiated from a NIB file,
		it automatically loads the plugins.
	
	REVISIONS:
		2003-07-31  UK  Created.
   -------------------------------------------------------------------------- */

-(void)		awakeFromNib
{
	[self scanForPlugins: self];
}


/* -----------------------------------------------------------------------------
	scanForPlugins:
		(Re)loads our list of plugins. You can use this as an action for a menu
		item, if you want.
		
		This scans the application's internal Plugins folder,
		~/Library/Application Support/ResKnife/Plugins/ and
		/Library/Application Support/ResKnife/Plugins/ for plugins that have
		the extension ".plugin" and implement initWithResource: (which means
		this won't get into the way if you want to support other kinds of
		plugins).
		
		It builds a registry of Class objects in an NSMutableDictionary, where
		the key is the resource type. If a plugin supports several resource
		types (as indicated by the RKEditedTypes key in its Info.plist), it
		will be registered for these types as well. If several plugins register
		for the same type, the last one loaded wins.
		
		To instantiate an object from a plugin, see the method below.
	
	TODO:
		Currently, Cocoa classes can't be unloaded, which means we're not
		leaking the NSBundles we load here. However, if this one day shouldn't
		hold true anymore, we'll want to retain these bundles in our dictionary
		and do the principalClass thingie in editorForType: instead, which
		allows us to get rid of the class and its bundle when reloading the
		plugin list by simply relying on NSMutableDictionary to release it.
	
	REVISIONS:
		2003-07-31  UK  Created.
   -------------------------------------------------------------------------- */

-(IBAction) scanForPlugins: (id)sender
{
	// TODO: Instead of hard-coding sysPath we should use some FindFolder-like API!
	Class			pluginClass;
	NSString		*appSupport = @"Library/Application Support/ResKnife/Plugins/";
	NSString		*appPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSString		*userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
	NSString		*sysPath = [@"/" stringByAppendingPathComponent:appSupport];
	NSArray			*paths = [NSArray arrayWithObjects:appPath, userPath, sysPath, nil];
	NSEnumerator	*pathEnum = [paths objectEnumerator];
	NSString		*path;
	
	if( typeRegistry )
		[typeRegistry release];
	typeRegistry = [[NSMutableDictionary alloc] init];
	
	while( path = [pathEnum nextObject] )
	{
		NSEnumerator *e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *name;
		
		NSLog(@"Looking for plugins at %@", path);
		
		while( name = [e nextObject] )
		{
			name = [path stringByAppendingPathComponent:name];
			NSLog(@"Examining %@", name);
			if( [[name pathExtension] isEqualToString:@"plugin"] )
			{
				NSBundle *plugin = [NSBundle bundleWithPath: name];
				
				NSLog(@"Identifier %@", [plugin bundleIdentifier]);
				if( pluginClass = [plugin principalClass] )
				{
					NSLog(@"Found plugin: %@", name);
					if( [pluginClass instancesRespondToSelector:@selector(initWithResource:)] )
					{
						NSString		*resType;
						NSArray			*types = [[plugin infoDictionary] objectForKey:@"RKEditedTypes"];
						NSEnumerator	*enny;
						
						if( types == nil )
							types = [NSArray arrayWithObject: [[plugin infoDictionary] objectForKey:@"RKEditedType"]];
						
						for( enny = [types objectEnumerator]; resType = [enny nextObject]; )
						{
							[typeRegistry setObject:pluginClass forKey:resType];
							NSLog(@"Registered for type %@.",resType);
						}
					}
				}
			}
		}
	}
}


/* -----------------------------------------------------------------------------
	editorForType:
		Looks up the editor for the specified type in our registry of plugins
		and returns the main class "object" that registered for this type, or
		Nil if there is none registered for this type.
		
		Note that the resource type is stored as an NSString, which means it
		can be longer than four characters (Currently used for looking up the
		Hexadecimal and Template editors, which are special in that they work
		with any resource).
	
	REVISIONS:
		2003-07-31  UK  Created.
   -------------------------------------------------------------------------- */

-(Class)	editorForType: (NSString*)typeStr
{
	Class		theClass = [typeRegistry objectForKey: typeStr];
	if( !theClass )
		return Nil;
	
	return theClass;
}

@end
