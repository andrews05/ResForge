RESKNIFE Snapshot 2003-08-02

WHAT IS IT?

This is a development snapshot of ResKnife, a resource editor for MacOS X. This is pre-pre-release software, do not use this on any vital files.


TRYING OUT RESKNIFE

There should be pre-built "deployment" binaries in the "build" folder. I've left the plugins in there as well, though you don't need to install them or anything like that, they're already installed.


BUILDING RESKNIFE

Currently the only project that I've confirmed will build is "ResKnife (PB2).pbproj". You can build the target "Cocoa ResKnife" as well as three Cocoa editor plugins that are in there. Of those, only the Hex editor really works. NovaTools doesn't register for the right types and the Template editor is far from finished.


BUILDING A PLUGIN

If you want to create a plugin for ResKnife, use the "ICONEditor" project as the basis. It's a simple, standalone project. You can install it in three places:

-> In ResKnife itself by selecting it, choosing "Information" and there clicking the "Add" button in the "plugins" section
-> In ~/Library/Application Support/ResKnife/Plugins/ for one user account.
-> In /Library/Application Support/ResKnife/Plugins/ for the entire machine.


ROAD MAP

I've decided to focus on the Cocoa version so we get a useable product done soon. The general consensus between Nick and me (Uli) is that he'll take care of the engine, while I'll focus mainly on plugins. However, since Nick is rather busy at the moment, I've made some changes to the engine that should allow plugin developers to get something done. All the basic features for editing resources in resource files should now be there. If you're missing any, tell me.


AUTHORS:
ResKnife was written by Nick Shanks (http://www.nickshanks.com) with additional changes by M. Uli Kusterer (http://www.zathras.de).

There is a web site for ResKnife at http://resknife.sourceforge.net

