#import "SoundWindowController.h"

@implementation SoundWindowController

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource {
    self = [self initWithWindowNibName:@"SoundWindow"];
    if (!self) return nil;
    
    _resource = newResource;
    if (_resource.data.length) {
        self.sound = [[SoundResource alloc] initWithResource:_resource];
    }
    
    [self window];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.channels.stringValue = self.sampleRate.stringValue = self.duration.stringValue = @"";
    if (!self.sound) {
        self.format.stringValue = @"(empty)";
    } else if (self.sound.format) {
        NSString *format = GetNSStringFromOSType(self.sound.format);
        if (self.sound.valid) {
            self.format.stringValue = SoundResource.supportedFormats[format];
            self.duration.stringValue = [self stringFromSeconds:self.sound.duration];
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
    }
}

- (NSString *)stringFromSeconds:(double)seconds {
    if (seconds < 10) {
        return [NSString stringWithFormat:@"%0.2fs", seconds];
    }
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%0.1fs", seconds];
    }
    long s = (long)round(seconds);
    return [NSString stringWithFormat:@"%02ld:%02ld", s/60, s%60];
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

- (IBAction)importSound:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"public.audio"];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            self.sound = [[SoundResource alloc] initWithURL:panel.URL format:'twos' channels:0 sampleRate:22050];
        }
    }];
}

@end
