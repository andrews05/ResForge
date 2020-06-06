#import "SoundWindowController.h"


@implementation SoundWindowController

- (instancetype)initWithResource:(id)newResource {
    self = [self initWithWindowNibName:@"SoundWindow"];
    if (!self) return nil;
    
    self.sound = [[SoundResource alloc] initWithResource:newResource];
    
    [self window];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.sound play];
}

- (void)dealloc {
    [self.sound stop];
}

- (IBAction)playSound:(id)sender {
    [self.sound play];
}

@end
