#import <Cocoa/Cocoa.h>

@interface DataSource : NSObject <NSComboBoxDataSource, NSComboBoxDelegate, NSFileManagerDelegate>
{
	OSType type;
	NSMutableDictionary *data;
	NSMutableArray *parsed;		// a subset of data, parsed to contain the typed string
}

- (id)initForType:(OSType)typeString;

- (NSDictionary *)data;
- (void)setData:(NSMutableDictionary *)newData;
- (void)setString:(NSString *)newData forResID:(int)resID;
- (void)parseForString:(NSString *)string sorted:(BOOL)sort;
- (void)parseForString:(NSString *)string withinRange:(NSRange)resIDRange sorted:(BOOL)sort;
- (id)objectValueForResID:(short)resID;
- (NSString *)stringValueForResID:(short)resID;
+ (short)resIDFromStringValue:(NSString *)string;
+ (NSString *)resNameFromStringValue:(NSString *)string;

@end
