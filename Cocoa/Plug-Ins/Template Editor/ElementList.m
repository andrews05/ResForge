#import "ElementList.h"

#import "ElementDBYT.h"
#import "ElementDWRD.h"
#import "ElementDLNG.h"
#import "ElementDLLG.h"
#import "ElementUBYT.h"
#import "ElementUWRD.h"
#import "ElementULNG.h"
#import "ElementULLG.h"
#import "ElementHBYT.h"
#import "ElementHWRD.h"
#import "ElementHLNG.h"
#import "ElementHLLG.h"
#import "ElementREAL.h"
#import "ElementDOUB.h"
#import "ElementFIXD.h"
#import "ElementFRAC.h"
#import "ElementAWRD.h"
#import "ElementFBYT.h"
#import "ElementPSTR.h"
#import "ElementCHAR.h"
#import "ElementTNAM.h"
#import "ElementBOOL.h"
#import "ElementBFLG.h"
#import "ElementWFLG.h"
#import "ElementLFLG.h"
#import "ElementBBIT.h"
#import "ElementWBIT.h"
#import "ElementLBIT.h"
#import "ElementRECT.h"
#import "ElementPNT.h"
#import "ElementHEXD.h"
#import "ElementDATE.h"
#import "ElementOCNT.h"
#import "ElementFCNT.h"
#import "ElementLSTB.h"
#import "ElementKEYB.h"
#import "ElementCASE.h"
#import "ElementKRID.h"
#import "ElementRSID.h"
#import "ElementCOLR.h"

@implementation ElementList

+ (instancetype)listFromStream:(NSInputStream *)stream
{
    return [[self alloc] initFromStream:stream];
}

- (instancetype)initFromStream:(NSInputStream *)stream
{
    self = [super init];
    if (!self) return nil;
    self.parsed = NO;
    self.elements = [NSMutableArray new];
    [stream open];
    Element *element;
    while ([stream hasBytesAvailable]) {
        element = [self readElementFromStream:stream];
        if (!element) break;
        [self.elements addObject:element];
    }
    [stream close];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ElementList *list = [[ElementList allocWithZone:zone] init];
    list.parsed = NO;
    list.controller = self.controller;
    list.elements = [[NSMutableArray allocWithZone:zone] initWithArray:self.elements copyItems:YES];
    [list parseElements];
    return list;
}

- (void)parseElements
{
    if (self.parsed) return;
    _currentIndex = 0;
    self.visibleElements = [NSMutableArray new];
    Element *element;
    while (_currentIndex < self.elements.count) {
        element = self.elements[_currentIndex];
        element.parentList = self;
        if (element.visible)
            [self.visibleElements addObject:element];
        [element readSubElements];
        _currentIndex++;
    }
    self.parsed = YES;
}

#pragma mark -

- (NSUInteger)count
{
    return self.visibleElements.count;
}

- (Element *)elementAtIndex:(NSUInteger)index
{
    return self.visibleElements[index];
}

// Insert a new element at the current position
- (void)insertElement:(Element *)element
{
    element.parentList = self;
    if (!self.parsed) {
        // Insert after current element during parsing (e.g. fixed count list, keyed section)
        [self.elements insertObject:element atIndex:++_currentIndex];
        [self.visibleElements addObject:element];
    } else {
        // Insert after current element during reading data (e.g. other lists)
        [self.elements insertObject:element atIndex:_currentIndex++];
        NSUInteger visIndex = [self.visibleElements indexOfObject:self.elements[_currentIndex]];
        [self.visibleElements insertObject:element atIndex:visIndex];
    }
}

// Insert a new element before/after a given element
- (void)insertElement:(Element *)element before:(Element *)before
{
    [self.elements insertObject:element atIndex:[self.elements indexOfObject:before]];
    element.parentList = self;
    [self.visibleElements insertObject:element atIndex:[self.visibleElements indexOfObject:before]];
}

- (void)insertElement:(Element *)element after:(Element *)after
{
    [self.elements insertObject:element atIndex:[self.elements indexOfObject:after]+1];
    element.parentList = self;
    [self.visibleElements insertObject:element atIndex:[self.visibleElements indexOfObject:after]+1];
}

- (void)removeElement:(Element *)element
{
    [self.elements removeObject:element];
    [self.visibleElements removeObject:element];
}

#pragma mark -

// The following methods may be used by elements while reading their sub elements

// Peek at an element in the list without removing it
- (Element *)peek:(NSUInteger)n
{
    n += _currentIndex;
    if (n >= self.elements.count)
        return nil;
    return self.elements[n];
}

// Pop the next element out of the list
- (Element *)pop
{
    if (_currentIndex+1 >= self.elements.count)
        return nil;
    Element *element = self.elements[_currentIndex+1];
    [self.elements removeObjectAtIndex:_currentIndex+1];
    return element;
}

// Search for an element of a given type following the current one
- (Element *)nextOfType:(NSString *)type
{
    Element *element;
    for (NSUInteger i = _currentIndex+1; i < self.elements.count; i++) {
        element = self.elements[i];
        if (!element) {
            NSLog(@"Element of type '%@' not found in template.", type);
            break;
        }
        if ([element.type isEqualToString:type])
            return element;
    }
    return nil;
}

// Create a new ElementList by extracting all elements following the current one up until a given type
- (ElementList *)subListFrom:(Element *)startElement
{
    ElementList *list = [ElementList new];
    list.controller = self.controller;
    list.elements = [NSMutableArray new];
    NSUInteger nesting = 0;
    Element *element;
    while (true) {
        element = [self pop];
        if (!element) {
            NSLog(@"Closing '%@' element not found for opening '%@'.", startElement.endType, startElement.type);
            break;
        }
        if ([element.endType isEqualToString:startElement.endType]) {
            nesting++;
        } else if ([element.type isEqualToString:startElement.endType]) {
            if (!nesting) break;
            nesting--;
        }
        [list.elements addObject:element];
    };
    return list;
}

#pragma mark -

- (void)readDataFrom:(ResourceStream *)stream
{
    _currentIndex = 0;
    // Don't use fast enumeration here as the list may be modified while reading
    while (_currentIndex < self.elements.count) {
        if (![stream bytesToGo]) return;
        [self.elements[_currentIndex] readDataFrom:stream];
        _currentIndex++;
    }
}

- (void)sizeOnDisk:(UInt32 *)size
{
    for (Element *element in self.elements) {
        [element sizeOnDisk:size];
    }
}

- (void)writeDataTo:(ResourceStream *)stream
{
    for (Element *element in self.elements) {
        [element writeDataTo:stream];
    }
}

#pragma mark -

- (Element *)readElementFromStream:(NSInputStream *)stream
{
    uint8_t sLength = 0;
    [stream read:&sLength maxLength:1];
    uint8_t *lBuffer = malloc(sLength);
    [stream read:lBuffer maxLength:sLength];
    NSString *label = [[NSString alloc] initWithBytesNoCopy:lBuffer length:sLength encoding:NSMacOSRomanStringEncoding freeWhenDone:YES];
    uint8_t *tBuffer = malloc(4);
    NSInteger bytesRead = [stream read:tBuffer maxLength:4];
    NSString *type = [[NSString alloc] initWithBytesNoCopy:tBuffer length:4 encoding:NSMacOSRomanStringEncoding freeWhenDone:YES];
    if (bytesRead != 4) {
        NSLog(@"Corrupt TMPL resource: not enough data.");
        return nil;
    }
    
    // create element class
    Class class = [self fieldRegistry][type];
    // check for Xnnn type - currently using resorcerer's nmm restriction to reserve all alpha types for potential future use
    if (!class && [type rangeOfString:@"[A-Z][0-9][0-9A-F]{2}" options:NSRegularExpressionSearch].location != NSNotFound) {
        class = [self fieldRegistry][[type substringToIndex:1]];
    }
    // check for XXnn type
    if (!class && [type rangeOfString:@"[A-Z]{2}[0-9]{2}" options:NSRegularExpressionSearch].location != NSNotFound) {
        class = [self fieldRegistry][[type substringToIndex:2]];
    }
    if (!class) {
        NSLog(@"Unrecognized template element type '%@'.", type);
        return nil;
    }
    return (Element *)[class elementForType:type withLabel:label];
}

- (NSMutableDictionary *)fieldRegistry
{
    static NSMutableDictionary *registry = nil;
    if (!registry) {
        registry = [[NSMutableDictionary alloc] init];
        
        // integers
        registry[@"DBYT"] = [ElementDBYT class];    // signed ints
        registry[@"DWRD"] = [ElementDWRD class];
        registry[@"DLNG"] = [ElementDLNG class];
        registry[@"DLLG"] = [ElementDLLG class];
        registry[@"UBYT"] = [ElementUBYT class];    // unsigned ints
        registry[@"UWRD"] = [ElementUWRD class];
        registry[@"ULNG"] = [ElementULNG class];
        registry[@"ULLG"] = [ElementULLG class];
        registry[@"HBYT"] = [ElementHBYT class];    // hex byte/word/long
        registry[@"HWRD"] = [ElementHWRD class];
        registry[@"HLNG"] = [ElementHLNG class];
        registry[@"HLLG"] = [ElementHLLG class];
        
        // multiple fields
        registry[@"RECT"] = [ElementRECT class];    // QuickDraw rect
        registry[@"PNT "] = [ElementPNT  class];    // QuickDraw point
        
        // align & fill
        registry[@"AWRD"] = [ElementAWRD class];    // alignment ints
        registry[@"ALNG"] = [ElementAWRD class];
        registry[@"AL08"] = [ElementAWRD class];
        registry[@"AL16"] = [ElementAWRD class];
        registry[@"FBYT"] = [ElementFBYT class];    // filler ints
        registry[@"FWRD"] = [ElementFBYT class];
        registry[@"FLNG"] = [ElementFBYT class];
        registry[@"FLLG"] = [ElementFBYT class];
        registry[@"F"]    = [ElementFBYT class];    // Fnnn
        
        // fractions
        registry[@"REAL"] = [ElementREAL class];    // single precision float
        registry[@"DOUB"] = [ElementDOUB class];    // double precision float
        registry[@"FIXD"] = [ElementFIXD class];    // 16.16 fixed fraction
        registry[@"FRAC"] = [ElementFRAC class];    // 2.30 fixed fraction
        
        // strings
        registry[@"PSTR"] = [ElementPSTR class];
        registry[@"BSTR"] = [ElementPSTR class];
        registry[@"WSTR"] = [ElementPSTR class];
        registry[@"LSTR"] = [ElementPSTR class];
        registry[@"OSTR"] = [ElementPSTR class];
        registry[@"ESTR"] = [ElementPSTR class];
        registry[@"CSTR"] = [ElementPSTR class];
        registry[@"OCST"] = [ElementPSTR class];
        registry[@"ECST"] = [ElementPSTR class];
        registry[@"P"]    = [ElementPSTR class];    // Pnnn
        registry[@"C"]    = [ElementPSTR class];    // Cnnn
        registry[@"CHAR"] = [ElementCHAR class];
        registry[@"TNAM"] = [ElementTNAM class];
        
        // bits
        registry[@"BOOL"] = [ElementBOOL class];    // true = 256; false = 0
        registry[@"BFLG"] = [ElementBFLG class];    // binary flag the size of a byte/word/long
        registry[@"WFLG"] = [ElementWFLG class];
        registry[@"LFLG"] = [ElementLFLG class];
        registry[@"BBIT"] = [ElementBBIT class];    // bit within a byte
        registry[@"BB"]   = [ElementBBIT class];    // BBnn bit field
        registry[@"BF"]   = [ElementBBIT class];    // BFnn fill bits
        registry[@"WBIT"] = [ElementWBIT class];
        registry[@"WB"]   = [ElementWBIT class];    // WBnn
        registry[@"WF"]   = [ElementWBIT class];    // WFnn
        registry[@"LBIT"] = [ElementLBIT class];
        registry[@"LB"]   = [ElementLBIT class];    // LBnn
        registry[@"LF"]   = [ElementLBIT class];    // LFnn
        
        // hex dumps
        registry[@"BHEX"] = [ElementHEXD class];
        registry[@"WHEX"] = [ElementHEXD class];
        registry[@"LHEX"] = [ElementHEXD class];
        registry[@"BSHX"] = [ElementHEXD class];
        registry[@"WSHX"] = [ElementHEXD class];
        registry[@"LSHX"] = [ElementHEXD class];
        registry[@"HEXD"] = [ElementHEXD class];
        registry[@"H"]    = [ElementHEXD class];    // Hnnn
        
        // list counters
        registry[@"OCNT"] = [ElementOCNT class];
        registry[@"ZCNT"] = [ElementOCNT class];
        registry[@"BCNT"] = [ElementOCNT class];
        registry[@"BZCT"] = [ElementOCNT class];
        registry[@"WCNT"] = [ElementOCNT class];
        registry[@"WZCT"] = [ElementOCNT class];
        registry[@"LCNT"] = [ElementOCNT class];
        registry[@"LZCT"] = [ElementOCNT class];
        registry[@"FCNT"] = [ElementFCNT class];    // fixed count with count in label (why not Lnnn?)
        // list begin/end
        registry[@"LSTB"] = [ElementLSTB class];
        registry[@"LSTZ"] = [ElementLSTB class];
        registry[@"LSTC"] = [ElementLSTB class];
        registry[@"LSTE"] = [Element     class];
        
        // option lists
        registry[@"CASE"] = [ElementCASE class];    // single option for preceding element
        registry[@"RSID"] = [ElementRSID class];    // resouce id (signed word) - type and offset in label
        
        // key selection
        registry[@"KBYT"] = [ElementDBYT class];    // signed keys
        registry[@"KWRD"] = [ElementDWRD class];
        registry[@"KLNG"] = [ElementDLNG class];
        registry[@"KLLG"] = [ElementDLLG class];
        registry[@"KUBT"] = [ElementUBYT class];    // unsigned keys
        registry[@"KUWD"] = [ElementUWRD class];
        registry[@"KULG"] = [ElementULNG class];
        registry[@"KULL"] = [ElementULLG class];
        registry[@"KHBT"] = [ElementHBYT class];    // hex keys
        registry[@"KHWD"] = [ElementHWRD class];
        registry[@"KHLG"] = [ElementHLNG class];
        registry[@"KHLL"] = [ElementHLLG class];
        registry[@"KCHR"] = [ElementCHAR class];    // keyed MacRoman values
        registry[@"KTYP"] = [ElementTNAM class];
        registry[@"KRID"] = [ElementKRID class];    // key on ID of the resource
        // keyed section begin/end
        registry[@"KEYB"] = [ElementKEYB class];
        registry[@"KEYE"] = [Element     class];
        
        // dates
        registry[@"DATE"] = [ElementDATE class];    // 4-byte date (seconds since 1 Jan 1904)
        registry[@"MDAT"] = [ElementDATE class];
        
        // colours
        registry[@"COLR"] = [ElementCOLR class];    // 6-byte QuickDraw colour
        registry[@"WCOL"] = [ElementCOLR class];    // 2-byte (15-bit) colour (Rezilla) - These appear to be EV Nova-specific additions
        registry[@"LCOL"] = [ElementCOLR class];    // 4-byte (24-bit) colour (Rezilla)
        
        registry[@"DVDR"] = [Element     class];    // divider
        
        // and some faked ones just to increase compatibility (these are marked 'x' in the docs)
        registry[@"SFRC"] = [ElementUWRD class];    // 0.16 fixed fraction
        registry[@"FXYZ"] = [ElementUWRD class];    // 1.15 fixed fraction
        registry[@"FWID"] = [ElementUWRD class];    // 4.12 fixed fraction
        registry[@"TITL"] = [Element     class];    // resource title (e.g. utxt would have "Unicode Text"; must be first element of template, and not anywhere else)
        registry[@"CMNT"] = [Element     class];
        registry[@"LLDT"] = [ElementULLG class];    // 8-byte date (LongDateTime; seconds since 1 Jan 1904)
        registry[@"STYL"] = [ElementDBYT class];    // QuickDraw font style
        registry[@"SCPC"] = [ElementDWRD class];    // MacOS script code (ScriptCode)
        registry[@"LNGC"] = [ElementDWRD class];    // MacOS language code (LangCode)
        registry[@"RGNC"] = [ElementDWRD class];    // MacOS region code (RegionCode)
        registry[@"BORV"] = [ElementHBYT class];    // Multiple select OR-value byte/word/long (Rezilla)
        registry[@"WORV"] = [ElementHWRD class];
        registry[@"LORV"] = [ElementHLNG class];
    }
    return registry;
}

@end
