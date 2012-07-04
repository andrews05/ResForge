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
#import "RKSupportResourceRegistry.h"
#import "NSString-FSSpec.h"		// for ResKnifeBoolExtensions (in wrong file)

/*!
@class			RKEditorRegistry
@author			Uli Kusterer
@created		2003-07-31
@description	This is a registry where all our resource-editor plugins are looked
				up and entered in a list, so you can ask for the editor for a specific
				resource type and it is returned immediately. This registry reads the
				types a plugin handles from their info.plist. This is better than
				encoding the type in the plugin file name, as file names are not
				guaranteed to be on a case-sensitive file system on Mac, and this also
				allows an editor to register for several resource types.
*/

@implementation RKEditorRegistry

/*!
@method			+defaultRegistry
@author			Uli Kusterer
@created		2003-07-31
@updated		2003-10-28 NGS: Changed method name from +mainRegistry (so it more closly matchs +defaultCenter) and moved global var inside method, making it a static.
@description	Returns the default plugin registry of this application, instantiating it first if there is none yet. As soon as this is instantiated, the plugins are loaded.
*/
+ (RKEditorRegistry *)defaultRegistry
{
	static RKEditorRegistry *defaultRegistry = nil;
	if(!defaultRegistry)
	{
		defaultRegistry = [[RKEditorRegistry alloc] init];
		[defaultRegistry scanForPlugins:nil];
	}
	return defaultRegistry;
}

/*!
@method			awakeFromNib
@abstract		Makes sure that if an instance of this is instantiated from a nib file, it automatically loads the plugins.
@author			Uli Kusterer
@created		2003-07-31
*/
- (void)awakeFromNib
{
	[self scanForPlugins:nil];
}

/*!
@method			scanForPlugins:
@abstract		(Re)loads our list of plugins. You can use this as an action for a menu item, if you want.
@author			Uli Kusterer
@created		2003-07-31
@updated		2003-10-28 NGS: Updated to look for more sophisticated RKSupportedTypes key in addition to (the now deprecated) RKEditedTypes.
@pending		Use NSSearchPathForDirectoriesInDomains() or equivalent to get folder paths instead of hard coding them.
@pending		Currently, Cocoa classes can't be unloaded, which means we're
				not leaking the NSBundles we load here. However, if this one
				day shouldn't hold true anymore, we'll want to retain these
				bundles in our dictionary and do the principalClass thingie
				in editorForType: instead, which allows us to get rid of the
				class and its bundle when reloading the plugin list by simply
				relying on NSMutableDictionary to release it.

@description	This scans the application's internal Plugins folder,
				<tt>~/Library/Application Support/ResKnife/Plugins/</tt> and
				<tt>/Library/Application Support/ResKnife/Plugins/</tt> for
				plugins that have the extension ".plugin" and implement
				<tt>initWithResource:</tt> (which means this won't get into
				the way if you want to support other kinds of plugins).</p>
				
				<p>It builds a registry of Class objects in an NSMutableDictionary,
				where the key is the resource type. If a plugin supports several
				resource types (as indicated by the RKEditedTypes key in it's
				Info.plist), it will be registered for these types as well.
				If several plugins register for the same type, the last one
				loaded wins.</p>
				
				<p>To instantiate an object from a plugin, see <tt>editorForType:</tt>
*/
- (IBAction)scanForPlugins:(id)sender
{
	NSString		*appSupport = @"Library/Application Support/ResKnife/Plugins/";
	NSString		*appPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSString		*userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
	NSString		*sysPath = [@"/" stringByAppendingPathComponent:appSupport];
//	NSArray			*paths = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES);
	NSEnumerator	*pathEnumerator = [[NSArray arrayWithObjects:appPath, userPath, sysPath, nil] objectEnumerator];
	NSString		*path;
	
	// release any existing registry to clear old values
	if(typeRegistry) [typeRegistry release];
	typeRegistry = [[NSMutableDictionary alloc] init];
	
	// scan all paths
	while(path = [pathEnumerator nextObject])
	{
		NSEnumerator *fileEnumerator = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] objectEnumerator];
		NSString *pluginName;
		
		// enumerate all files in this directory
		while(pluginName = [fileEnumerator nextObject])
		{
			NSString *pluginPath = [path stringByAppendingPathComponent:pluginName];
//			NSLog(@"Examining %@", pluginPath);
			
			// verify file is a plugin
			if([[pluginName pathExtension] isEqualToString:@"plugin"])
			{
				NSBundle *plugin = [NSBundle bundleWithPath:pluginPath];
				Class pluginClass = [plugin principalClass];
				if(plugin && pluginClass)
				{
//					NSLog(@"Principal class %@ %@ to ResKnifePluginProtocol", NSStringFromClass(pluginClass), [pluginClass conformsToProtocol:@protocol(ResKnifePluginProtocol)]? @"conforms":@"does not conform");
					
					// check principal class implements ResKnifePluginProtocol
					if([pluginClass conformsToProtocol:@protocol(ResKnifePluginProtocol)])
					{
						NSArray *supportedTypes = [[plugin infoDictionary] objectForKey:@"RKSupportedTypes"];
						if(supportedTypes)
						{
							NSDictionary *typeEntry;
							NSEnumerator *typesEnumerator = [supportedTypes objectEnumerator];
							
							// enumerate entries
							while(typeEntry = [typesEnumerator nextObject])
							{
								// get values for type entry
								NSString *name = [typeEntry objectForKey:@"RKTypeName"];
//								NSString *role = [typeEntry objectForKey:@"RKTypeRole"];
//								BOOL isDefault = [(NSString *)[typeEntry objectForKey:@"IsResKnifeDefaultForType"] boolValue];
								
								// register them
								[typeRegistry setObject:pluginClass forKey:name];		// bug: very primative, doesn't use extra data
//								NSLog(@"Plug-in class %@ registered as %@%@ for type %@.", NSStringFromClass(pluginClass), isDefault? @"default ":@"", role, name);
							}
						}
						else
						{
							// try the old way of looking up types
							NSString		*resType;
							NSEnumerator	*enny;
							supportedTypes = [[plugin infoDictionary] objectForKey:@"RKEditedTypes"];
							if(supportedTypes == nil)
								supportedTypes = [NSArray arrayWithObject: [[plugin infoDictionary] objectForKey:@"RKEditedType"]];
							
							for(enny = [supportedTypes objectEnumerator]; resType = [enny nextObject];)
							{
								[typeRegistry setObject:pluginClass forKey:resType];
//								NSLog(@"Registered for type %@.",resType);
							}
						}
						
						// load any support resources in the plug-in
						[RKSupportResourceRegistry scanForSupportResourcesInFolder:[[plugin resourcePath] stringByAppendingPathComponent:@"Support Resources"]];
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

- (Class)editorForType:(NSString *)typeStr
{
	Class theClass = [typeRegistry objectForKey: typeStr];
	if(!theClass) return Nil;
	else return theClass;
}

@end
