#import "ElementDATE.h"

@implementation ElementDATE

- (id)copyWithZone:(NSZone *)zone
{
	ElementDATE *element = [super copyWithZone:zone];
	[element setValue:value];
	return element;
}

- (void)readDataFrom:(TemplateStream *)stream
{
	[stream readAmount:sizeof(value) toBuffer:&value];
}

- (unsigned int)sizeOnDisk
{
	return sizeof(value);
}

- (void)writeDataTo:(TemplateStream *)stream
{
	[stream writeAmount:sizeof(value) fromBuffer:&value];
}

- (UInt32)value
{
	return value;
}

- (void)setValue:(UInt32)v
{
	value = v;
}

- (NSString *)stringValue
{
	CFAbsoluteTime cfTime;
	OSStatus error = UCConvertSecondsToCFAbsoluteTime(value, &cfTime);
	if(error) return nil;
//	return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] descriptionWithLocale:[NSLocale currentLocale]];
	return [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
	//return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] descriptionWithLocale:[NSDictionary dictionaryWithObject:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString] forKey:@"NSTimeDateFormatString"]];
//	return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] descriptionWithLocale:[NSDictionary dictionaryWithObjectsAndKeys:
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString], @"NSTimeDateFormatString",
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSAMPMDesignation], @"NSAMPMDesignation",
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSMonthNameArray], @"NSMonthNameArray",
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSShortMonthNameArray], @"NSShortMonthNameArray",
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSWeekDayNameArray], @"NSWeekDayNameArray",
//		[[NSUserDefaults standardUserDefaults] objectForKey:NSShortWeekDayNameArray], @"NSShortWeekDayNameArray",
//		nil]];
//	return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] descriptionWithLocale:[NSDictionary dictionaryWithObject:[[NSCalendar currentCalendar] calendarIdentifier] forKey:@"NSLocaleCalendar"]];
//	return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)cfTime] descriptionWithCalendarFormat:[NSCalendar currentCalendar]];// timeZone:[NSTimeZone localTimeZone] locale:[NSDictionary dictionaryWithObject:[NSCalendar currentCalendar] forKey:@"NSLocaleCalendar"]];

}

- (void)setStringValue:(NSString *)str
{
//	UCConvertCFAbsoluteTimeToSeconds((CFAbsoluteTime)[[NSCalendarDate dateWithString:str] timeIntervalSinceReferenceDate], &value);
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSDate *date = [formatter dateFromString:str];
	UCConvertCFAbsoluteTimeToSeconds((CFAbsoluteTime)[date timeIntervalSinceReferenceDate], &value);
//	UCConvertCFAbsoluteTimeToSeconds((CFAbsoluteTime)[[NSCalendarDate dateWithNaturalLanguageString:str locale:[NSDictionary dictionaryWithObject:[NSLocale currentLocale] forKey:@"NSLocale"]] timeIntervalSinceReferenceDate], &value);
}

@end
