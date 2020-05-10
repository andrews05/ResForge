#import "Element.h"

@interface ElementCaseable : Element
@property (strong) NSMutableArray *cases;
@property (strong) NSMutableDictionary *caseMap;

@end


@interface NTInsensitiveComboBoxCell : NSComboBoxCell
@property CGFloat rightMargin;

@end
