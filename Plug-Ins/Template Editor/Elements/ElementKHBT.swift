import Cocoa

// Implements KHBT, KHWD, KHLG, KHLL
class ElementKHBT<T: FixedWidthInteger & UnsignedInteger>: ElementKBYT<T> {
    override class var formatter: Formatter? {
        return ElementHBYT<T>.formatter
    }
}
