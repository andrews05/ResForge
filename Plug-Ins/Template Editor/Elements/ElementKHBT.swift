import Cocoa

// Implements KHBT, KHWD, KHLG, KHQD
class ElementKHBT<T: FixedWidthInteger & UnsignedInteger>: ElementKBYT<T> {
    override var formatter: Formatter {
        self.sharedFormatter("HEX\(T.bitWidth)") { HexFormatter<T>() }
    }
}
