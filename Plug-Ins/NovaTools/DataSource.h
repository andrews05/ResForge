#import <Cocoa/Cocoa.h>

@interface DataSource : NSObject <NSComboBoxDataSource, NSComboBoxDelegate, NSFileManagerDelegate, NSComboBoxCellDataSource, NSTokenFieldCellDelegate>
{
	OSType type;
	NSMutableDictionary *data;
	NSMutableArray *parsed;		// a subset of data, parsed to contain the typed string
}

- (instancetype)initForType:(OSType)typeString;

- (NSDictionary *)data;
- (void)setData:(NSMutableDictionary *)newData;
- (void)setString:(NSString *)newData forResID:(ResID)resID;
- (void)parseForString:(NSString *)string sorted:(BOOL)sort;
- (void)parseForString:(NSString *)string withinRange:(NSRange)resIDRange sorted:(BOOL)sort;
- (id)objectValueForResID:(ResID)resID;
- (NSString *)stringValueForResID:(ResID)resID;
+ (short)resIDFromStringValue:(NSString *)string;
+ (NSString *)resNameFromStringValue:(NSString *)string;

@end
