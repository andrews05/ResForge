#import "TemplateStream.h"
#import "Element.h"
#import "ElementOCNT.h"	// for tracking current counter
#import "ElementHEXD.h"	// for errors

#import "ElementDBYT.h"
#import "ElementDWRD.h"
#import "ElementDLNG.h"
#import "ElementDLLG.h"
#import "ElementUBYT.h"
#import "ElementUWRD.h"
#import "ElementULNG.h"
#import "ElementULLG.h"
#import "ElementFIXD.h"
#import "ElementFRAC.h"
#import "ElementAWRD.h"
#import "ElementFBYT.h"
#import "ElementPSTR.h"
#import "ElementBFLG.h"
#import "ElementWFLG.h"
#import "ElementLFLG.h"
#import "ElementBOOL.h"
#import "ElementRECT.h"
#import "ElementPNT.h"
//#import "ElementHEXD.h"
#import "ElementDATE.h"
//#import "ElementOCNT.h"
#import "ElementFCNT.h"
#import "ElementLSTB.h"
#import "ElementLSTC.h"
#import "ElementLSTE.h"
#import "ElementKEYB.h"

@implementation TemplateStream
@synthesize length;
@synthesize bytesToGo;

+ (id)streamWithBytes:(char *)d length:(UInt32)l
{
	return [[self alloc] initStreamWithBytes:d length:l];
}

+ (id)substreamWithStream:(TemplateStream *)s length:(UInt32)l
{
	return [[self alloc] initWithStream:s length:l];
}

- (instancetype)initStreamWithBytes:(char *)d length:(UInt32)l
{
	self = [super init];
	if(!self) return nil;
	data = d;
    length = l;
	bytesToGo = l;
	counterStack = [[NSMutableArray alloc] init];
	keyStack = [[NSMutableArray alloc] init];
	return self;
}

- (instancetype)initWithStream:(TemplateStream *)s length:(UInt32)l
{
	return [self initStreamWithBytes:[s data] length:MIN(l, [s bytesToGo])];
}

- (char *)data
{
	return data;
}

- (UInt32)bytesToNull
{
	UInt32 dist = 0;
	while(dist < bytesToGo)
	{
		if(*(char *)(data+dist) == 0x00)
			return dist;
		dist++;
	}
	return bytesToGo;
}

- (ElementOCNT *)counter
{
	return (ElementOCNT *) [counterStack lastObject];
}

- (void)pushCounter:(ElementOCNT *)c
{
	[counterStack addObject:c];
}

- (void)popCounter
{
	[counterStack removeLastObject];
}

- (Element *)key
{
	NSLog(@"Getting last key of stack: %@", keyStack);
	return [keyStack lastObject];
}

- (void)pushKey:(Element *)k
{
	[keyStack addObject:k];
	NSLog(@"Pushed key to stack: %@", keyStack);
}

- (void)popKey
{
	NSLog(@"Popping key from stack: %@", keyStack);
	[keyStack removeLastObject];
}

#pragma mark -

- (Element *)readOneElement
{
	// check where pointer will be AFTER having loaded this element
	NSString *type = nil, *label = nil;
	if(*data + 5 <= bytesToGo)
	{
		bytesToGo -= *data + 5;
		label = [[NSString alloc] initWithBytes:data+1 length:*data encoding:NSMacOSRomanStringEncoding];
		data += *data +1;
		type = [[NSString alloc] initWithBytes:data length:4 encoding:NSMacOSRomanStringEncoding];
		data += 4;
	}
	else
	{
		bytesToGo = 0;
		NSLog(@"Corrupt TMPL resource: not enough data. Dumping remaining resource as hex.");
		return [ElementHEXD elementForType:@"HEXD" withLabel:NSLocalizedString(@"Error: Hex Dump", nil)];
	}
	
	// create element class
	Class class = [self fieldRegistry][type];
    // check for Xnnn type - currently using resorcerer's nmm restriction to prevent false matches
    if(!class && [type rangeOfString:@"[A-Z][0-9][0-9A-F]{2}" options:NSRegularExpressionSearch].location != NSNotFound)
    {
        class = [self fieldRegistry][[type substringToIndex:1]];
    }
	if(class)
	{
		Element *element = (Element *) [class elementForType:type withLabel:label];
		[element readSubElementsFrom:self];
		return element;
    }
    else
	{
		bytesToGo = 0;
		NSLog(@"Class not found for template element type '%@'. Dumping remaining resource as hex.", type);
		return [ElementHEXD elementForType:@"HEXD" withLabel:NSLocalizedString(@"Error: Hex Dump", nil)];
	}
}

- (void)advanceAmount:(UInt32)l pad:(BOOL)pad
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0)
	{
		if(pad) memset(data, 0, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)peekAmount:(UInt32)l toBuffer:(void *)buffer
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0) memmove(buffer, data, l);
}

- (void)readAmount:(UInt32)l toBuffer:(void *)buffer
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0)
	{
		memmove(buffer, data, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)writeAmount:(UInt32)l fromBuffer:(const void *)buffer
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0)
	{
		memmove(data, buffer, l);
		data += l;
		bytesToGo -= l;
	}
}

#pragma mark -
#pragma mark Misc

- (NSMutableDictionary *)fieldRegistry
{
	static NSMutableDictionary *registry = nil;
	if(!registry)
	{
		registry = [[NSMutableDictionary alloc] init];
		
	// integers
		registry[@"DBYT"] = [ElementDBYT class];	// signed ints
		registry[@"DWRD"] = [ElementDWRD class];
		registry[@"DLNG"] = [ElementDLNG class];
		registry[@"DLLG"] = [ElementDLLG class];
		registry[@"UBYT"] = [ElementUBYT class];	// unsigned ints
		registry[@"UWRD"] = [ElementUWRD class];
		registry[@"ULNG"] = [ElementULNG class];
		registry[@"ULLG"] = [ElementULLG class];
        
    // multiple fields
        registry[@"RECT"] = [ElementRECT class];    // QuickDraw rect
        registry[@"PNT "] = [ElementPNT  class];    // QuickDraw point
        
    // align & fill
        registry[@"AWRD"] = [ElementAWRD class];    // alignment ints
        registry[@"ALNG"] = [ElementAWRD class];
        registry[@"AL08"] = [ElementAWRD class];
        registry[@"AL16"] = [ElementAWRD class];
		registry[@"FBYT"] = [ElementFBYT class];	// filler ints
		registry[@"FWRD"] = [ElementFBYT class];
		registry[@"FLNG"] = [ElementFBYT class];
		registry[@"FLLG"] = [ElementFBYT class];
        registry[@"F"]    = [ElementFBYT class];    // Fnnn
		
	// fractions
		registry[@"FIXD"] = [ElementFIXD class];	// 16.16 fixed fraction
		registry[@"FRAC"] = [ElementFRAC class];	// 2.30 fixed fraction
		
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
		registry[@"CHAR"] = [ElementPSTR class];
		registry[@"TNAM"] = [ElementPSTR class];
        registry[@"P"]    = [ElementPSTR class];    // Pnnn
        registry[@"C"]    = [ElementPSTR class];    // Cnnn
        
    // checkboxes
        registry[@"BFLG"] = [ElementBFLG class];    // binary flag the size of a byte/word/long
        registry[@"WFLG"] = [ElementWFLG class];
        registry[@"LFLG"] = [ElementLFLG class];
        registry[@"BOOL"] = [ElementBOOL class];    // true = 256; false = 0
		
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
        registry[@"FCNT"] = [ElementFCNT class];
	// list begin/end
		registry[@"LSTC"] = [ElementLSTC class];
		registry[@"LSTB"] = [ElementLSTB class];
		registry[@"LSTZ"] = [ElementLSTB class];
		registry[@"LSTE"] = [ElementLSTE class];
	// key begin/end
		registry[@"KEYB"] = [ElementKEYB class];
		registry[@"KEYE"] = [ElementKEYE class];
		
	// dates
		registry[@"DATE"] = [ElementDATE class];	// 4-byte date (seconds since 1 Jan 1904)
		registry[@"MDAT"] = [ElementDATE class];
		
	// and some faked ones just to increase compatibility (these are marked 'x' in the docs)
		registry[@"HBYT"] = [ElementUBYT class];	// hex byte/word/long
		registry[@"HWRD"] = [ElementUWRD class];
		registry[@"HLNG"] = [ElementULNG class];
		registry[@"HLLG"] = [ElementULLG class];
		registry[@"KBYT"] = [ElementKBYT class];	// signed keys
		registry[@"KWRD"] = [ElementKWRD class];
		registry[@"KLNG"] = [ElementKLNG class];
		registry[@"KLLG"] = [ElementDLLG class];
		registry[@"KUBT"] = [ElementUBYT class];	// unsigned keys
		registry[@"KUWD"] = [ElementUWRD class];
		registry[@"KULG"] = [ElementULNG class];
		registry[@"KULL"] = [ElementULLG class];
		registry[@"KHBT"] = [ElementUBYT class];	// hex keys
		registry[@"KHWD"] = [ElementUWRD class];
		registry[@"KHLG"] = [ElementULNG class];
		registry[@"KHLL"] = [ElementULLG class];
		registry[@"KCHR"] = [ElementPSTR class];	// keyed MacRoman values
		registry[@"KTYP"] = [ElementPSTR class];
		registry[@"KRID"] = [ElementFBYT class];	// key on ID of the resource
		registry[@"RSID"] = [ElementDWRD class];	// resouce id (signed word)
		registry[@"REAL"] = [ElementULNG class];	// single precision float
		registry[@"DOUB"] = [ElementULLG class];	// double precision float
		registry[@"SFRC"] = [ElementUWRD class];	// 0.16 fixed fraction
		registry[@"FXYZ"] = [ElementUWRD class];	// 1.15 fixed fraction
		registry[@"FWID"] = [ElementUWRD class];	// 4.12 fixed fraction
		registry[@"CASE"] = [ElementFBYT class];
		registry[@"TITL"] = [ElementFBYT class];	// resource title (e.g. utxt would have "Unicode Text"; must be first element of template, and not anywhere else)
		registry[@"CMNT"] = [ElementFBYT class];
		registry[@"DVDR"] = [ElementFBYT class];
		registry[@"LLDT"] = [ElementULLG class];	// 8-byte date (LongDateTime; seconds since 1 Jan 1904)
		registry[@"STYL"] = [ElementDBYT class];	// QuickDraw font style
		registry[@"SCPC"] = [ElementDWRD class];	// MacOS script code (ScriptCode)
		registry[@"LNGC"] = [ElementDWRD class];	// MacOS language code (LangCode)
		registry[@"RGNC"] = [ElementDWRD class];	// MacOS region code (RegionCode)
		
	// unhandled types at present, see file:///Users/nicholas/Sites/resknife.sf.net/resorcerer_comparison.html
		// BBIT, BBnn, FBIT, FBnn, WBIT, WBnn
	}
	return registry;
}

@end
