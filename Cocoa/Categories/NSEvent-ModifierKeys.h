#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>

@interface NSEvent (NGSModifierKeys)

+ (BOOL)isControlKeyDown;
+ (BOOL)isOptionKeyDown;
+ (BOOL)isCommandKeyDown;
+ (BOOL)isShiftKeyDown;

@end