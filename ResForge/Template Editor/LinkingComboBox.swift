import Cocoa

// An extension of NSComboBox that allows displaying a link button inside the cell
// This is used by RSID and CASR to open referenced resources
class LinkingComboBox: NSComboBox {
    override class var cellClass: AnyClass? {
        get { LinkingComboBoxCell.self }
        set { }
    }

    private let linkButton: NSButton
    var showsLink: Bool {
        (delegate as? LinkingComboBoxDelegate)?.showsLink == true
    }

    override init(frame frameRect: NSRect) {
        let buttonFrame = NSRect(x: frameRect.size.width - 36, y: 6, width: 12, height: 12)
        linkButton = NSButton(frame: buttonFrame)
        super.init(frame: frameRect)
        linkButton.isBordered = false
        linkButton.bezelStyle = .inline
        linkButton.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
        if #unavailable(macOS 11) {
            linkButton.imageScaling = .scaleProportionallyDown
        }
        linkButton.target = self
        linkButton.action = #selector(followLink(_:))
        self.addSubview(linkButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        if linkButton.isHidden == showsLink {
            // Toggle the button visibility
            linkButton.isHidden = !linkButton.isHidden
            // If currently editing the field, the clip view frame will need updating
            if let clip = subviews.last as? NSClipView {
                var frame = clip.frame
                frame.size.width += linkButton.isHidden ? 16 : -16
                clip.frame = frame
            }
        }
        super.draw(dirtyRect)
    }

    @objc private func followLink(_ sender: Any) {
        // Ensure value is committed before following link
        if self.currentEditor() == nil || self.window?.makeFirstResponder(nil) != false {
            (delegate as? LinkingComboBoxDelegate)?.followLink(sender)
        }
    }
}

class LinkingComboBoxCell: NSComboBoxCell {
    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // Ensure the text does not overlap the link button
        var r = super.drawingRect(forBounds: rect)
        if let control = controlView as? LinkingComboBox, control.showsLink {
            r.size.width -= 16
        }
        return r
    }
}

@objc protocol LinkingComboBoxDelegate: NSComboBoxDelegate {
    var showsLink: Bool { get }
    func followLink(_ sender: Any)
}
