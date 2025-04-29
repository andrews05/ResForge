import AppKit

class LinkingLayer: CAShapeLayer {
    var source: SystemView?
    var targets: [SystemView] = []
    var target: SystemView? {
        // Prefer the rightmost system when there are multiple under the cursor
        targets.max { $0.point.x < $1.point.x }
    }
    private var flagsMonitor: Any?

    override init() {
        super.init()
        // Initial state for transition
        fillColor = nil
        strokeColor = nil
        lineWidth = 4
        // Watch event flags to see if the colour needs to change
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.setNeedsDisplay()
            return event
        }
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
    }

    override func display() {
        guard let source, let window = source.window else {
            fillColor = nil
            strokeColor = nil
            lineWidth = 4
            // Allow fade out if target set, otherwise clear immediately
            if targets.isEmpty {
                path = nil
            }
            return
        }

        let remove = NSEvent.modifierFlags.contains(.option)
        let color: NSColor = if target == nil {
            remove ? .systemOrange : .systemBlue
        } else {
            remove ? .systemRed : .systemGreen
        }
        fillColor = color.cgColor
        strokeColor = color.cgColor
        lineWidth = 2

        let path = CGMutablePath()
        let sourceRect = CGRect(origin: source.point, size: .zero).insetBy(dx: -3, dy: -3)
        path.addEllipse(in: sourceRect)
        path.move(to: source.point)
        if let target {
            path.addLine(to: target.point)
            let targetRect = CGRect(origin: target.point, size: .zero).insetBy(dx: -3, dy: -3)
            path.addEllipse(in: targetRect)
        } else {
            let to = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            path.addLine(to: to)
        }
        self.path = path
    }
}
