import AppKit

/// A number formatter that disallows blank values.
public class NonBlankNumberFormatter: NumberFormatter {
    // The nilSymbol is by default an empty string. This means that when the field is an empty string, the formatter's object value is nil, potentially causing an exception if bound to a variable that doesn't allow nil. We can prevent this by setting the nilSymbol to a null character - a string which cannot be entered into the field.
    public override var nilSymbol: String {
        get { "\0" }
        set { }
    }
}
