#import "SoundWindowController.h"
#import "SoundResource.h"

@implementation SoundWindowController

- (instancetype)initWithResource:(id)newResource
{
    self = [self initWithWindowNibName:@"SoundWindow"];
    if (!self) return nil;
    
    _resource = newResource;
    
    SoundResource *sound = [[SoundResource alloc] initWithResource:_resource];
    
//    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:<#(double)#> channels:<#(AVAudioChannelCount)#>];
//    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:<#(nonnull AVAudioFormat *)#> frameCapacity:<#(AVAudioFrameCount)#>
    
    [self window];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
