import AppKit

// An extension of NSComboBox that allows displaying a link button inside the cell
// This is used by RSID and CASR to open referenced resources
class LinkingComboBox: NSComboBox {
    override class var cellClass: AnyClass? {
        get { LinkingComboBoxCell.self }
        set { }
    }

    private let linkButton: NSButton
    var linkIcon: String? {
        (delegate as? LinkingComboBoxDelegate)?.linkIcon
    }

    override init(frame frameRect: NSRect) {
        var buttonFrame = NSRect(x: frameRect.width - 38, y: 4, width: 16, height: 16)
        if #available(macOS 26, *) {
            buttonFrame.origin.x -= 1
        }
        linkButton = NSButton(frame: buttonFrame)
        super.init(frame: frameRect)
        linkButton.isBordered = false
        linkButton.bezelStyle = .inline
        linkButton.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: nil)
        linkButton.target = self
        linkButton.action = #selector(followLink(_:))
        self.addSubview(linkButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        if let linkIcon {
            linkButton.image = NSImage(systemSymbolName: linkIcon, accessibilityDescription: nil)
        }
        if linkButton.isHidden != (linkIcon == nil) {
            // Toggle the button visibility
            linkButton.isHidden = !linkButton.isHidden
            // If currently editing the field, the clip view frame will need updating
            for clip in subviews where clip is NSClipView {
                var frame = clip.frame
                frame.size.width += linkButton.isHidden ? 16 : -16
                clip.frame = frame
            }
        }
        super.draw(dirtyRect)
    }

    @objc private func followLink(_ sender: Any) {
        // Ensure value is committed and link is still valid before following
        if self.currentEditor() == nil || (self.window?.makeFirstResponder(nil) != false && linkIcon != nil) {
            (delegate as? LinkingComboBoxDelegate)?.followLink(sender)
        }
    }
}

class LinkingComboBoxCell: NSComboBoxCell {
    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // Ensure the text does not overlap the link button
        var dRect = super.drawingRect(forBounds: rect)
        if let control = controlView as? LinkingComboBox, control.linkIcon != nil {
            dRect.size.width -= 16
        }
        return dRect
    }

    // On macOS 26 we need to adjust both the drawingRect (when editing) and the interior (when not editing)
    // On earlier versions, we only need to adjust one
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var dRect = cellFrame
        if #available(macOS 26, *), let control = controlView as? LinkingComboBox, control.linkIcon != nil {
            dRect.size.width -= 16
        }
        super.drawInterior(withFrame: dRect, in: controlView)
    }
}

@objc protocol LinkingComboBoxDelegate: NSComboBoxDelegate {
    var linkIcon: String? { get }
    func followLink(_ sender: Any)
}
