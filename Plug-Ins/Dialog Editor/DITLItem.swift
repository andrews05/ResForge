import Foundation
import RFSupport

struct DITLItem {
    
    var itemView: DITLItemView
    var enabled: Bool
    var itemType: DITLItemType
    var resourceID: Int // Only SInt16, but let's be consistent with ResForge's Resource type.
    var helpItemType = DITLHelpItemType.unknown
    var itemNumber = Int16(0)
}
