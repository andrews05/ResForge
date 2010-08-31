/*
									* * * * * * * * * * * * *
										RESKNIFE  READ-ME
									* * * * * * * * * * * * *
																		Last updated: 9 November 2003
WHAT IS IT?
-----------

This is a development snapshot of ResKnife, a resource editor for the Macintosh. This is pre-release software and as such should only be used with copies of files, or on files you don't mind being destroyed :)


TRYING OUT RESKNIFE
-------------------

Prebuilt binaries of ResKnife are available from http://resknife.sourceforge.net/ for MacOS 7.1 through to 10.3
Please download them and try it out. If you like what you see, please tell us. If you don't like what you see, please tell us too!
ResKnife is an open-source editor and contributions from any and all are welcomed.


BUILDING RESKNIFE
-----------------

The source code for ResKnife is also available from http://resknife.sourceforge.net/ as a released source package corrisponding to the latest officially released binary, or as a nightly tarball. If you are familiar with CVS you may also download the code via anonymous cvs access from :pserver:anonymous@cvs.resknife.sourceforge.net/cvsroot/resknife as project 'ResKnife'.
ResKnife can be built as either a Cocoa app, Carbon app or Classic app, the Carbon version available in either MachO or PEF formats, using your choice of either CodeWarrior or Xcode/Project Builder (gcc 2.95, 3.1 or 3.3) as IDE/compiler. The Classic and Carbon versionsd are build from the same codebase, with the main differences being TARGET_API_MAC_CARBON being set on the latter, and linking against CarbonLib instead of InterfaceLib et al. When building the Carbon version as a Package, you can choose to use nib files instead of resources to define things like menus and dialogue boxes. The Carbon/Classic version is no longer maintained by the original developer, though you are free to work on it if you wish. The Cocoa version has a compleatly different codebase, and is the current focus of development. It is considered the most bug-free and most feature-compleate ('most' being about 20% as compared with 15% for Carbon).


BUILDING A PLUGIN
-----------------

If you want to create a Cocoa plugin for ResKnife, use the "ICONEditor" project as the basis until the SDK is available. It's a simple, standalone project. You can install it in three places:

-> In ResKnife itself by selecting it, choosing "Information" and there clicking the "Add" button in the "plugins" section
-> In ~/Library/Application Support/ResKnife/Plugins/ for one user account.
-> In /Library/Application Support/ResKnife/Plugins/ for the entire machine.

If you want to create a plugin for the Carbon version of ResKnife, take a look at the Hex Editor try to derivesomething from that. Editors for the Classic version 


ROAD MAP
--------

Currently Uli and Nicholas have decided to delegate different parts of the project to each other, with Nick handling the host application and hex editor, and Uli handling the template editor. Nicholas is also working on an editor for resources associated with the game Escape Velocity Nova by Ambrosia Software. Other editors will be written as time permits, or perhaps by third parties such as yourself! If you have any ideas for editors, take a look at the SDK (avalable from the web site) which contains an empty 'shell' editor. Sample fully-working editors are of course available as part of the project themselves!

HISTORY
-------

ResKnife has had a protracted and erratic history. It started in 1997 when Nicholas Shanks decided ResEdit needed a successor and because he wanted to play around with the new resources available with Mac OS 8.0, yet didn't have the money to buy Resourcerer. After three months of fast R&D, version 0.1d9 was quite stable and had many features, including a working hex editor. Then in a careless act of stupidity, Nicholas decided to Carbonise the program without backing up the 0.1d9 source. It failed, and much that once was had been lost. Throwing away that mess and starting again, Nicholas tried to re-write ResKnife as a Carbon app from the ground up. Thrice. Versions 0.2 and 0.3 were aborted attempts to do this, version 0.4 was more successful, and now forms the basis for the Carbon varient of ResKnife. Soon after, the wonders of Cocoa were discovered and required learning, and Nicholas turned to his pet project ResKnife to help him learn. The Cocoa re-write became version 0.5 and in conjunction with version 0.4 which had had a few touch-ups added to it since, was committed to CVS almost two years after the last commit had occured. Two more years passed with not much change to ResKnife, before Uli Kusterer, collaborator for earlier versions of ResKnife and himself writing a resource editor with special consideration for users of the MacZoop framework, decided to write a template editor for the project. Throughout the development of the project contributions small and large have trickled in, and all who contributed are recognised below.


AUTHORS
-------

ResKnife was written by Nicholas Shanks http://web.nickshanks.com/ with additional changes and some editors supplied by M. Uli Kusterer http://www.zathras.de/
Other contributors include (in alphabetical order): Thomas Castiglione, Philippe Devallois, Mike Margolis, Lane Roathe and Jeffrey Seibert.
There is a web site for ResKnife at http://resknife.sourceforge.net/


COMMENTS FOR THOSE WHO WISH TO CONTRIBUTE
-----------------------------------------

Please try to conform to the existing formatting rules followed, including placement of braces and use of whitespace, and tabs rather than space characters for indenting. Tab width is four.


Notes on commenting/documenting for the ResKnife project:

ResKnife methods, functions, headers, classes, ivars and practically anything else is commented using the format specified by HeaderDoc (a C-based equivalent to JavaDoc), although with ResKnife-specific modifications (NB: although I've yet to modify HeaderDoc to read these new parameters, they should still be used for the time being). The general format is to use the standard C block-commenting mechanism, with the addition of an exclamation mark immediatly after the open comment marker. Following this are one or more lines beginning with an at sign, a keyword, arguments if any, and finally a string value. For source code consistancy, I (Nicholas) am suggesting the following when documenting an object.

	1) All HeaderDoc comments immediatly preceede the object to which they pertain.
	2) HeaderDoc comments documenting a method or function must follow the following order (for consistancy & readability), where an ellipsis indicates the line above can be repeated multiple times:
		
		@method or @function
		@abstract
		@author
		@created
		@updated		[significant changes that other developers should be aware of; ordered reverse chronological, i.e. most recent at the top]
		 ...
		@pending		[higher priority TODO items should be above lower priority ones]
		 ...
		@description
		@param			[listed in order taken by method/function]
		 ...
	
	3) The pertinent keywords or their equivalents in the above item should retain the specified order wherever reasonably applicable (e.g. for @class and @protocol comments)
	4) The value for the @created keyword should take the following form:	YYYY-MM-DD
	5) The value for the @updated keyword should take the following form:	YYYY-MM-DD Author: Description
		where Author is your initials or sourceforge user name.
	
	Due to really poor maintance on my part, very few methods have @updated comments. Sorry :-(
*/
