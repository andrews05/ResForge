import AppKit

class AltLayer: BaseLayer {
    override var currentFrame: NSBitmapImageRep? {
        guard frames.count > 0 else {
            return nil
        }
        let index = (controller.framesPerSet * currentSet) + controller.currentFrame
        return frames[index % frames.count]
    }
    @objc dynamic var setCount = 0
    @objc dynamic var hideDisabled = false
    private var currentSet = 0
    private var setTicks = 0

    override func nextFrame() {
        if enabled && setCount > 0 {
            setTicks += 1
            if setTicks >= controller.animationDelay {
                currentSet = (currentSet + 1) % setCount
                setTicks = 0
            }
        }
    }
}
