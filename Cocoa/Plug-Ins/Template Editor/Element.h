#import <Foundation/Foundation.h>

@interface Element : NSObject
{
	NSString 		*type;
	NSString		*label;	
	union	// for resource arrays only, ignored for TMPL arrays
	{
		NSString	*string;
		NSNumber	*number;
		NSData		*data;
		BOOL		boolean;
	} elementData;
}

- (id)initWithType:(NSString *)typeValue andLabel:(NSString *)labelValue;
+ (id)elementOfType:(NSString *)typeValue withLabel:(NSString *)labelValue;

- (NSString *)label;
- (NSString *)type;
- (unsigned long)typeAsLong;
- (NSString *)string;
- (void)setString:(NSString *)string;
- (NSNumber *)number;
- (void)setNumber:(NSNumber *)number;
- (long)numberAsLong;
- (void)setNumberWithLong:(long)number;
- (NSData *)data;
- (void)setData:(NSData *)data;
- (BOOL)boolean;
- (void)setBoolean:(BOOL)boolean;

@end
