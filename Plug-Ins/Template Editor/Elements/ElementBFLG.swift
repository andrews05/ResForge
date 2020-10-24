import Cocoa

// Implements BFLG, WFLG, LFLG
class ElementBFLG<T: FixedWidthInteger & UnsignedInteger>: ElementDBYT<T> {
    override func configure() throws {
        // Empty to override to disallow cases
    }
    
    override func configure(view: NSView) {
        view.addSubview(ElementBOOL.createCheckbox(with: view.frame, for: self))
    }
}
