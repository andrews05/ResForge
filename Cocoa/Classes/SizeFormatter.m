#import "SizeFormatter.h"

@implementation SizeFormatter

- (void)awakeFromNib
{
	[self setFormat:@"#,##0.0"];
	[self setLocalizesFormat:YES];
	[self setAllowsFloats:YES];
}

- (NSString *)stringForObjectValue:(id)obj
{
	NSMutableString *string = [NSMutableString string];
	float value = [obj floatValue];
	int power = 0;
			
	while( value >= 1024 && power <= 30 )
	{
		power += 10;	// 10 == KB, 20 == MB, 30 == GB
		value /= 1024;
	}
	
	switch( power )
	{
		case 0:
			[string appendFormat:@"%.0f", value];
			break;
		
		case 10:
			[string appendFormat:@"%.1f KB", value];
			break;
		
		case 20:
			[string appendFormat:@"%.1f MB", value];
			break;
		
		default:
			[string appendFormat:@"%.1f GB", value];
			break;
	}
	return string;
}

@end
