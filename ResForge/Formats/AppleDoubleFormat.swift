import Foundation
import RFSupport

class AppleDoubleFormat: AppleSingleFormat {
    // AppleDouble has no defined extension or UTI - use a generic one
    override class var typeName: String { "public.archive" }
    override var name: String { NSLocalizedString("AppleDouble Archive", comment: "") }

    override class var signature: UInt32 { 0x00051607 }
}
