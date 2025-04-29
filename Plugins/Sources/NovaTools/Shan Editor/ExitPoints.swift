import AppKit

class ExitPoints: NSObject {
    @objc var enabled = false
    @objc var point1 = ExitPoint()
    @objc var point2 = ExitPoint()
    @objc var point3 = ExitPoint()
    @objc var point4 = ExitPoint()
    let points: [ExitPoint]
    private let color: NSColor

    init(_ color: NSColor) {
        points = [
            point1,
            point2,
            point3,
            point4
        ]
        self.color = color
    }

    func draw(_ transform: AffineTransform) {
        guard enabled else {
            return
        }
        color.setFill()
        let size = NSSize(width: 3, height: 3)
        for point in points {
            var origin = NSPoint(x: point.x, y: point.y)
            origin = transform.transform(origin)
            origin.x.round()
            origin.y.round()
            origin.x -= 1
            origin.y += point.z - 1
            NSRect(origin: origin, size: size).frame()
        }
    }
}

class ExitPoint: NSObject {
    weak var controller: ShanWindowController?
    @objc dynamic var x: CGFloat = 0
    @objc dynamic var y: CGFloat = 0
    @objc dynamic var z: CGFloat = 0

    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        controller?.setDocumentEdited(true)
    }
}
