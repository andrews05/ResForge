#import <Foundation/Foundation.h>

@class	Element;
@interface TemplateStream : NSObject
{
	char *data;
	unsigned int bytesToGo;
	NSMutableArray *counterStack;
	NSMutableArray *keyStack;
}

+ (id)streamWithBytes:(char *)d length:(unsigned int)l;
+ (id)substreamWithStream:(TemplateStream *)s length:(unsigned int)l;

- (id)initStreamWithBytes:(char *)d length:(unsigned int)l;
- (id)initWithStream:(TemplateStream *)s length:(unsigned int)l;

- (char *)data;
- (unsigned int)bytesToGo;
- (void)setBytesToGo:(unsigned int)b;
- (Element *)counter;
- (void)pushCounter:(Element *)c;
- (void)popCounter;
- (Element *)key;
- (void)pushKey:(Element *)k;
- (void)popKey;

- (Element *)readOneElement;	// For parsing of 'TMPL' resource as template.
- (unsigned int)bytesToNull;
- (void)advanceAmount:(unsigned int)l pad:(BOOL)pad;					// advance r/w pointer and optionally write padding bytes
- (void)peekAmount:(unsigned int)l toBuffer:(void *)buffer;				// read bytes without advancing pointer
- (void)readAmount:(unsigned int)l toBuffer:(void *)buffer;				// stream reading
- (void)writeAmount:(unsigned int)l fromBuffer:(const void *)buffer;	// stream writing
- (NSMutableDictionary *)fieldRegistry;

@end
