#import <Foundation/Foundation.h>

@class	Element, ElementOCNT;
@interface TemplateStream : NSObject
{
	char *data;
	NSMutableArray *counterStack;
	NSMutableArray *keyStack;
}

@property UInt32 length;
@property UInt32 bytesToGo;

+ (instancetype)streamWithBytes:(char *)d length:(UInt32)l;
+ (instancetype)substreamWithStream:(TemplateStream *)s length:(UInt32)l;

- (instancetype)initStreamWithBytes:(char *)d length:(UInt32)l;
- (instancetype)initWithStream:(TemplateStream *)s length:(UInt32)l;

- (char *)data;
- (ElementOCNT *)counter;
- (void)pushCounter:(ElementOCNT *)c;
- (void)popCounter;
- (Element *)key;
- (void)pushKey:(Element *)k;
- (void)popKey;

- (Element *)readOneElement;	// For parsing of 'TMPL' resource as template.
- (UInt32)bytesToNull;
- (void)advanceAmount:(UInt32)l pad:(BOOL)pad;					// advance r/w pointer and optionally write padding bytes
- (void)peekAmount:(UInt32)l toBuffer:(void *)buffer;				// read bytes without advancing pointer
- (void)readAmount:(UInt32)l toBuffer:(void *)buffer;				// stream reading
- (void)writeAmount:(UInt32)l fromBuffer:(const void *)buffer;	// stream writing
- (NSMutableDictionary *)fieldRegistry;

@end
