#import "SoundWindowController.h"

@implementation SoundWindowController

- (instancetype)initWithResource:(id)newResource {
    self = [self initWithWindowNibName:@"SoundWindow"];
    if (!self) return nil;
    
    _resource = newResource;
    self.sound = [[SoundResource alloc] initWithResource:_resource];
    
    [self window];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    if (self.sound.format) {
        NSString *format = GetNSStringFromOSType(self.sound.format);
        if (SoundResource.supportedFormats[format]) {
            self.format.stringValue = SoundResource.supportedFormats[format];
            self.playButton.enabled = YES;
            self.exportButton.enabled = YES;
            [self.sound play];
        } else {
            self.format.stringValue = [NSString stringWithFormat:@"%@ (unsupported)", format];
        }
        self.channels.stringValue = self.sound.channels == 2 ? @"Stereo" : @"Mono";
        self.sampleRate.stringValue = [NSString stringWithFormat:@"%.0f Hz", self.sound.sampleRate];
    } else {
        self.format.stringValue = @"(unknown)";
        self.channels.stringValue = self.sampleRate.stringValue = @"";
    }
}

- (void)dealloc {
    [self.sound stop];
}

- (IBAction)playSound:(id)sender {
    [self.sound play];
}

- (IBAction)exportSound:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    if (_resource.name.length) {
        panel.nameFieldStringValue = _resource.name;
    } else {
        panel.nameFieldStringValue = [NSString stringWithFormat:@"Sound %d", _resource.resID];
    }
    panel.allowedFileTypes = @[@"aiff"];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            [self.sound exportToURL:panel.URL];
        }
    }];
}

@end
