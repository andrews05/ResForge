import RFSupport

protocol NCBExpression {
    static var usage: String { get }
    static func parse(_ input: String) throws -> Self
    func description(manager: RFEditorManager) -> String
}
