#import "ElementPNT.h"

@implementation ElementPNT
@synthesize top;
@synthesize left;

- (id)copyWithZone:(NSZone*)zone
{
    ElementPNT *element = [super copyWithZone:zone];
    element.top = top;
    element.left = left;
    return element;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.hasThousandSeparators = NO;
    formatter.minimum = @(INT16_MIN);
    formatter.maximum = @(INT16_MAX);
    
    NSTableCellView *view = [outlineView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    NSTextField *top = view.textField;
    NSRect frame = top.frame;
    frame.size.width = 56;
    top.frame = frame;
    top.autoresizingMask ^= NSViewWidthSizable;
    top.editable = YES;
    top.delegate = self;
    top.formatter = formatter;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:top];
    [top bind:@"value" toObject:self withKeyPath:@"top" options:nil];
    
    NSTextField *left = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    frame.origin.x += frame.size.width+4;
    left.frame = frame;
    left.delegate = self;
    [left bind:@"value" toObject:self withKeyPath:@"left" options:nil];
    [view addSubview:left];
    
    return view;
}

- (void)readDataFrom:(TemplateStream *)stream
{
    SInt16 tmp = 0;
    [stream readAmount:2 toBuffer:&tmp];
    top = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    left = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 4;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(top);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(left);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
