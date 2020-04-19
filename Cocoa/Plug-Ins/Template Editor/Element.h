#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "TemplateStream.h"

/*
	This is the base class for all template field types. Subclass this to
	define a field type of your own.
	
	Note that subclasses *must* implement the NSCopying protocol, which means
	if you have instance variables, you must provide your own copyWithZone:
	implementation that calls through to the superclass and then copies its
	own variables' values (or retains references to them, if that is more
	effective and the object in question isn't mutable).
*/

@interface Element : NSObject <NSCopying, NSTextFieldDelegate>
// Accessors:
@property (copy) NSString *type; // Type code of this item (4 chars if from TMPL resource, but we may support longer types later).
@property (copy) NSString *label; // Label ("name") of this field.
@property (weak) NSMutableArray *parentArray; // The NSMutableArray* of the template field containing us, or the template window's list.
@property BOOL isTMPL;// for debugging

+ (instancetype)elementForType:(NSString *)type withLabel:(NSString *)label;
- (instancetype)initForType:(NSString *)type withLabel:(NSString *)label;

// This is used to instantiate copies of the item from the template for storing data of the resource. A copy created with this is then sent readDataFrom:.
- (id)copyWithZone:(NSZone *)zone;

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn;

- (NSString *)stringValue; // Used to display your data in the list.
- (BOOL)editable;

// Items that have sub-items (like LSTB, LSTZ, LSTC and other lists) should implement these:
- (NSInteger)subElementCount;
- (Element *)subElementAtIndex:(NSInteger)n;
- (void)readSubElementsFrom:(TemplateStream *)stream;

// This is called on an item of your class when displaying resource data using a template that uses your field:
- (void)readDataFrom:(TemplateStream *)stream;

// The following are used to write resource data back out:
- (UInt32)sizeOnDisk:(UInt32)currentSize;
- (void)writeDataTo:(TemplateStream *)stream;

/* Apart from these messages, a Element may also implement the IBActions for
	the standard edit commands (cut, copy, paste, clear). When an element is selected,
	the template editor will forward any calls to these items to the element, if it
	implements them, and it will automatically enable the appropriate menu items. It
	will also forward validateMenuItem:for the Paste menu item to the element.
	
	The createListEntry:action will also be forwarded to elements by the
	template editor. Use this to allow creating new list items or for similar
	purposes ("Create New Resource..." is renamed to "Create List Entry" while the
	template editor is key). */

@end
