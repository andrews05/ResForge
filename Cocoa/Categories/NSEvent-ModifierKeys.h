#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>

@interface NSEvent (ModifierKeys)

+ (BOOL) isControlKeyDown;
+ (BOOL) isOptionKeyDown;
+ (BOOL) isCommandKeyDown;
+ (BOOL) isShiftKeyDown;

@end