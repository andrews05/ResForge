#import "PrefsController.h"

NSString * const kPreserveBackups = @"PreserveBackups";
NSString * const kAutosave = @"Autosave";
NSString * const kAutosaveInterval = @"AutosaveInterval";
NSString * const kDeleteResourceWarning =  @"DeleteResourceWarning";
NSString * const kLaunchAction = @"LaunchAction";
NSString * const kOpenUntitledFile = @"OpenUntitledFile";
NSString * const kDisplayOpenPanel = @"DisplayOpenPanel";
NSString * const kNoLaunchOption = @"None";

// Transform launch action matrix index to string constants
@implementation PrefsController

+ (NSArray *)launchActions {
    static NSArray *launchActions = nil;
    if (!launchActions)
        launchActions = @[kNoLaunchOption, kOpenUntitledFile, kDisplayOpenPanel];
    return launchActions;
    
}

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value
{
    return @([self.class.launchActions indexOfObject:value]);
}

- (id)reverseTransformedValue:(id)value
{
    return self.class.launchActions[[value intValue]];
}

@end
