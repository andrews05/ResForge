//
//  RKSupportResourceRegistry.m
//  ResKnife
//
//  Created by Uli Kusterer on Mon Aug 18 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "RKSupportResourceRegistry.h"


@implementation RKSupportResourceRegistry

+(void) scanForSupportResources: (NSDocumentController*)c
{
	// TODO: Instead of hard-coding sysPath we should use some FindFolder-like API!
	NSString		*appSupport = @"Library/Application Support/ResKnife/Support Resources/";
	NSString		*appPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Support Resources"];
	NSString		*userPath = [NSHomeDirectory() stringByAppendingPathComponent:appSupport];
	NSString		*sysPath = [@"/" stringByAppendingPathComponent:appSupport];
	NSArray			*paths = [NSArray arrayWithObjects:appPath, userPath, sysPath, nil];
	NSEnumerator	*pathEnum = [paths objectEnumerator];
	NSString		*path;
	
	while( path = [pathEnum nextObject] )
	{
		NSEnumerator	*e = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString		*name;
	
		NSLog(@"Looking for resources in %@", path);
		
		while( name = [e nextObject] )
		{
			name = [path stringByAppendingPathComponent:name];
			NSLog(@"Examining %@", name);
			if( [[name pathExtension] isEqualToString:@"rsrc"] )
			{
				[c openDocumentWithContentsOfFile:name display:YES];
				//[[[[[c openDocumentWithContentsOfFile:name display:YES] windowControllers] objectAtIndex:0] window] orderOut: self];
			}
		}
	}
}

@end
