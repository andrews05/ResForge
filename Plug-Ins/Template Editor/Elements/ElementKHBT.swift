import Cocoa

// Implements KHBT, KHWD, KHLG, KHQD
class ElementKHBT<T: FixedWidthInteger & UnsignedInteger>: ElementKBYT<T> {
    override class var formatter: Formatter? {
        return ElementHBYT<T>.formatter
    }
}
