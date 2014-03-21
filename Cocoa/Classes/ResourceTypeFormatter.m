//
//  ResourceTypeFormatter.m
//  ResKnife
//
//  Created by C.W. Betts on 3/21/14.
//
//

#import "ResourceTypeFormatter.h"
#import "ResKnifeResourceProtocol.h"

@implementation ResourceTypeFormatter

- (NSString *)stringForObjectValue:(id)obj;
{
	if ([obj isKindOfClass:[NSNumber class]]) {
		OSType tmpType = [obj unsignedIntValue];
		NSString *tmpStr = GetNSStringFromOSType(tmpType);
		if (!tmpStr) {
			tmpStr = [[NSString alloc] initWithFormat:@"%X", (unsigned int)tmpType];
		}
		return tmpStr;
	}
	return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error;
{
	OSType tmpType = GetOSTypeFromNSString(string);
	if (tmpType) {
		*obj = @(tmpType);
	} else {
		unsigned int retVal = 0;
		NSScanner *tmpScan = [NSScanner scannerWithString:string];
		if (![tmpScan scanHexInt:&retVal]) {
			return NO;
		}
		*obj = @(retVal);
	}
	
	return YES;
}

@end
