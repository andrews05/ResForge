#import "ElementDWRD.h"

@interface ElementRSID : ElementDWRD
@property NSString *resType;
@property int offset;
@property int max;
@property NSMutableArray *fixedCases;

+ (void)configureLinkButton:(NSComboBox *)comboBox forElement:(Element *)element;

@end
