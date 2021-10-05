import Cocoa

class SteppingFieldDelegate: NSObject, NSTextFieldDelegate {
    // Increment/decrement the value with up/down keypress
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSControl.moveUp(_:)):
            control.integerValue += 1
        case #selector(NSControl.moveDown(_:)):
            control.integerValue -= 1
        case #selector(NSControl.cancelOperation(_:)):
            // Abort editing on escape
            control.abortEditing()
            return true
        default:
            return false
        }
        // To propagate the change to a bound value we first need to trigger a user change
        textView.insertText("", replacementRange: NSMakeRange(0, 0))
        // Then commit the change
        textView.insertNewline(self)
        return true
    }
}
