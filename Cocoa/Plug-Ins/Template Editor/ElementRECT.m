#import "ElementRECT.h"

@implementation ElementRECT
@synthesize top;
@synthesize left;
@synthesize bottom;
@synthesize right;

- (id)copyWithZone:(NSZone*)zone
{
    ElementRECT *element = [super copyWithZone:zone];
    element.top = top;
    element.left = left;
    element.bottom = bottom;
    element.right = right;
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
    
    NSTextField *bottom = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    frame.origin.x += frame.size.width+4;
    bottom.frame = frame;
    bottom.delegate = self;
    [bottom bind:@"value" toObject:self withKeyPath:@"bottom" options:nil];
    [view addSubview:bottom];
    
    NSTextField *right = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    frame.origin.x += frame.size.width+4;
    right.frame = frame;
    right.delegate = self;
    [right bind:@"value" toObject:self withKeyPath:@"right" options:nil];
    [view addSubview:right];
    
    return view;
}

- (void)readDataFrom:(TemplateStream *)stream
{
    SInt16 tmp = 0;
    [stream readAmount:2 toBuffer:&tmp];
    top = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    left = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    bottom = CFSwapInt16BigToHost(tmp);
    [stream readAmount:2 toBuffer:&tmp];
    right = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return 8;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    SInt16 tmp = CFSwapInt16HostToBig(top);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(left);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(bottom);
    [stream writeAmount:2 fromBuffer:&tmp];
    tmp = CFSwapInt16HostToBig(right);
    [stream writeAmount:2 fromBuffer:&tmp];
}

@end
