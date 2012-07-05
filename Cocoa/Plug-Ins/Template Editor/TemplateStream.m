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
#import "ElementFBYT.h"
#import "ElementPSTR.h"
//#import "ElementHEXD.h"
#import "ElementDATE.h"
//#import "ElementOCNT.h"
#import "ElementLSTB.h"
#import "ElementLSTC.h"
#import "ElementLSTE.h"
#import "ElementKEYB.h"

@implementation TemplateStream

+ (id)streamWithBytes:(char *)d length:(unsigned int)l
{
	return [[[self alloc] initStreamWithBytes:d length:l] autorelease];
}

+ (id)substreamWithStream:(TemplateStream *)s length:(unsigned int)l
{
	return [[[self alloc] initWithStream:s length:l] autorelease];
}

- (id)initStreamWithBytes:(char *)d length:(unsigned int)l
{
	self = [super init];
	if(!self) return nil;
	data = d;
	bytesToGo = l;
	counterStack = [[NSMutableArray alloc] init];
	keyStack = [[NSMutableArray alloc] init];
	return self;
}

- (id)initWithStream:(TemplateStream *)s length:(unsigned int)l
{
	return [self initStreamWithBytes:[s data] length:MIN(l, [s bytesToGo])];
}

- (void)dealloc
{
	[counterStack release];
	[keyStack release];
	[super dealloc];
}

- (char *)data
{
	return data;
}

- (unsigned int)bytesToGo
{
	return bytesToGo;
}

- (void)setBytesToGo:(unsigned int)b
{
	bytesToGo = b;
}

- (unsigned int)bytesToNull
{
	unsigned int dist = 0;
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
	return [counterStack lastObject];
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
		label = [[[NSString alloc] initWithBytes:data+1 length:*data encoding:NSMacOSRomanStringEncoding] autorelease];
		data += *data +1;
		type = [[[NSString alloc] initWithBytes:data length:4 encoding:NSMacOSRomanStringEncoding] autorelease];
		data += 4;
	}
	else
	{
		bytesToGo = 0;
		NSLog(@"Corrupt TMPL resource: not enough data. Dumping remaining resource as hex.");
		return [ElementHEXD elementForType:@"HEXD" withLabel:NSLocalizedString(@"Error: Hex Dump", nil)];
	}
	
	// create element class
	Class class = [[self fieldRegistry] objectForKey:type];
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

- (void)advanceAmount:(unsigned int)l pad:(BOOL)pad
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0)
	{
		if(pad) memset(data, 0, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)peekAmount:(unsigned int)l toBuffer:(void *)buffer
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0) memmove(buffer, data, l);
}

- (void)readAmount:(unsigned int)l toBuffer:(void *)buffer
{
	if(l > bytesToGo) l = bytesToGo;
	if(l > 0)
	{
		memmove(buffer, data, l);
		data += l;
		bytesToGo -= l;
	}
}

- (void)writeAmount:(unsigned int)l fromBuffer:(const void *)buffer
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
		[registry setObject:[ElementDBYT class] forKey:@"DBYT"];	// signed ints
		[registry setObject:[ElementDWRD class] forKey:@"DWRD"];
		[registry setObject:[ElementDLNG class] forKey:@"DLNG"];
		[registry setObject:[ElementDLLG class] forKey:@"DLLG"];
		[registry setObject:[ElementUBYT class] forKey:@"UBYT"];	// unsigned ints
		[registry setObject:[ElementUWRD class] forKey:@"UWRD"];
		[registry setObject:[ElementULNG class] forKey:@"ULNG"];
		[registry setObject:[ElementULLG class] forKey:@"ULLG"];
		[registry setObject:[ElementFBYT class] forKey:@"FBYT"];	// filler ints
		[registry setObject:[ElementFBYT class] forKey:@"FWRD"];
		[registry setObject:[ElementFBYT class] forKey:@"FLNG"];
		[registry setObject:[ElementFBYT class] forKey:@"FLLG"];
		
	// fractions
		[registry setObject:[ElementFIXD class] forKey:@"FIXD"];	// 16.16 fixed fraction
		[registry setObject:[ElementFRAC class] forKey:@"FRAC"];	// 2.30 fixed fraction
		
	// strings
		[registry setObject:[ElementPSTR class] forKey:@"PSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"BSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"WSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"LSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"OSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"ESTR"];
		[registry setObject:[ElementPSTR class] forKey:@"CSTR"];
		[registry setObject:[ElementPSTR class] forKey:@"OCST"];
		[registry setObject:[ElementPSTR class] forKey:@"ECST"];
		[registry setObject:[ElementPSTR class] forKey:@"CHAR"];
		[registry setObject:[ElementPSTR class] forKey:@"TNAM"];
		
	// hex dumps
		[registry setObject:[ElementHEXD class] forKey:@"HEXD"];
		
	// list counters
		[registry setObject:[ElementOCNT class] forKey:@"OCNT"];
		[registry setObject:[ElementOCNT class] forKey:@"ZCNT"];
		[registry setObject:[ElementOCNT class] forKey:@"BCNT"];
		[registry setObject:[ElementOCNT class] forKey:@"BZCT"];
		[registry setObject:[ElementOCNT class] forKey:@"WCNT"];
		[registry setObject:[ElementOCNT class] forKey:@"WZCT"];
		[registry setObject:[ElementOCNT class] forKey:@"LCNT"];
		[registry setObject:[ElementOCNT class] forKey:@"LZCT"];
	// list begin/end
		[registry setObject:[ElementLSTC class] forKey:@"LSTC"];
		[registry setObject:[ElementLSTB class] forKey:@"LSTB"];
		[registry setObject:[ElementLSTB class] forKey:@"LSTZ"];
		[registry setObject:[ElementLSTE class] forKey:@"LSTE"];
	// key begin/end
		[registry setObject:[ElementKEYB class] forKey:@"KEYB"];
		[registry setObject:[ElementKEYE class] forKey:@"KEYE"];
		
	// dates
		[registry setObject:[ElementDATE class] forKey:@"DATE"];	// 4-byte date (seconds since 1 Jan 1904)
		[registry setObject:[ElementDATE class] forKey:@"MDAT"];
		
	// and some faked ones just to increase compatibility (these are marked 'x' in the docs)
		[registry setObject:[ElementUBYT class] forKey:@"HBYT"];	// hex byte/word/long
		[registry setObject:[ElementUWRD class] forKey:@"HWRD"];
		[registry setObject:[ElementULNG class] forKey:@"HLNG"];
		[registry setObject:[ElementULLG class] forKey:@"HLLG"];
		[registry setObject:[ElementKBYT class] forKey:@"KBYT"];	// signed keys
		[registry setObject:[ElementKWRD class] forKey:@"KWRD"];
		[registry setObject:[ElementKLNG class] forKey:@"KLNG"];
		[registry setObject:[ElementDLLG class] forKey:@"KLLG"];
		[registry setObject:[ElementUBYT class] forKey:@"KUBT"];	// unsigned keys
		[registry setObject:[ElementUWRD class] forKey:@"KUWD"];
		[registry setObject:[ElementULNG class] forKey:@"KULG"];
		[registry setObject:[ElementULLG class] forKey:@"KULL"];
		[registry setObject:[ElementUBYT class] forKey:@"KHBT"];	// hex keys
		[registry setObject:[ElementUWRD class] forKey:@"KHWD"];
		[registry setObject:[ElementULNG class] forKey:@"KHLG"];
		[registry setObject:[ElementULLG class] forKey:@"KHLL"];
		[registry setObject:[ElementPSTR class] forKey:@"KCHR"];	// keyed MacRoman values
		[registry setObject:[ElementPSTR class] forKey:@"KTYP"];
		[registry setObject:[ElementFBYT class] forKey:@"KRID"];	// key on ID of the resource
		[registry setObject:[ElementUWRD class] forKey:@"BOOL"];	// true = 256; false = 0
		[registry setObject:[ElementUBYT class] forKey:@"BFLG"];	// binary flag the size of a byte/word/long
		[registry setObject:[ElementUWRD class] forKey:@"WFLG"];
		[registry setObject:[ElementULNG class] forKey:@"LFLG"];
		[registry setObject:[ElementDWRD class] forKey:@"RSID"];	// resouce id (signed word)
		[registry setObject:[ElementULNG class] forKey:@"REAL"];	// single precision float
		[registry setObject:[ElementULLG class] forKey:@"DOUB"];	// double precision float
		[registry setObject:[ElementUWRD class] forKey:@"SFRC"];	// 0.16 fixed fraction
		[registry setObject:[ElementUWRD class] forKey:@"FXYZ"];	// 1.15 fixed fraction
		[registry setObject:[ElementUWRD class] forKey:@"FWID"];	// 4.12 fixed fraction
		[registry setObject:[ElementFBYT class] forKey:@"CASE"];
		[registry setObject:[ElementFBYT class] forKey:@"TITL"];	// resource title (e.g. utxt would have "Unicode Text"; must be first element of template, and not anywhere else)
		[registry setObject:[ElementFBYT class] forKey:@"CMNT"];
		[registry setObject:[ElementFBYT class] forKey:@"DVDR"];
		[registry setObject:[ElementULLG class] forKey:@"LLDT"];	// 8-byte date (LongDateTime; seconds since 1 Jan 1904)
		[registry setObject:[ElementDBYT class] forKey:@"STYL"];	// QuickDraw font style
		[registry setObject:[ElementULNG class] forKey:@"PNT "];	// QuickDraw point
		[registry setObject:[ElementULLG class] forKey:@"RECT"];	// QuickDraw rect
		[registry setObject:[ElementDWRD class] forKey:@"SCPC"];	// MacOS script code (ScriptCode)
		[registry setObject:[ElementDWRD class] forKey:@"LNGC"];	// MacOS language code (LangCode)
		[registry setObject:[ElementDWRD class] forKey:@"RGNC"];	// MacOS region code (RegionCode)
		
	// unhandled types at present, see file:///Users/nicholas/Sites/resknife.sf.net/resorcerer_comparison.html
		// BBIT, BBnn, FBIT, FBnn, WBIT, WBnn
		// Pnnn, Cnnn, Hnnn, Fnnn, HEXD
		// AWRD, ALNG (not so easy, element needs to know how much data preceeds it in the stream)
	}
	return registry;
}

@end
