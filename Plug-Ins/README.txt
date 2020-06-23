NOTES OF INTEREST:

A ResKnife plugin declares the types it edits in its Info.plist-file. Just add
the key "RKEditedType" to the plist, which should be a string containing the
resource's type. If you want to have it edit several types, use "RKEditedTypes"
(note the "s" at the end) instead, which is an array of type strings.

You can also specify "Hexadecimal Editor" instead of a type code if you
want to provide a replacement for the built-in Hex editor, or "Template
Editor" for replacing the template editor. Note that the template editor uses
a different entrypoint (initWithResources:) than the other editors.

Apart from that, this is a standard Cocoa plugin.

