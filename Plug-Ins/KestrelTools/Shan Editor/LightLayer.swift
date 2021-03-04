import Cocoa

class LightLayer: SpriteLayer {
    @IBOutlet var labelA: NSTextField!
    @IBOutlet var labelB: NSTextField!
    @IBOutlet var labelC: NSTextField!
    @IBOutlet var labelD: NSTextField!
    @objc dynamic var blinkMode: Int16 = 0 {
        didSet {
            hideValues = false
            hideD = false
            switch blinkMode {
            case 1:
                labelA.stringValue = "Off Time"
                labelB.stringValue = "On Time"
                labelC.stringValue = "Group Count"
                labelD.stringValue = "Group Delay"
            case 2:
                labelA.stringValue = "Min (1-32)"
                labelB.stringValue = "Up Speed"
                labelC.stringValue = "Max (1-32)"
                labelD.stringValue = "Down Speed"
            case 3:
                labelA.stringValue = "Min (1-32)"
                labelB.stringValue = "Max (1-32)"
                labelC.stringValue = "Delay"
                hideD = true
            default:
                hideValues = true
                hideD = true
            }
            controller.setDocumentEdited(true)
        }
    }
    @objc dynamic var blinkValueA: Int16 = 0
    @objc dynamic var blinkValueB: Int16 = 0
    @objc dynamic var blinkValueC: Int16 = 0
    @objc dynamic var blinkValueD: Int16 = 0
    @objc dynamic var hideValues = true
    @objc dynamic var hideD = true
    @objc dynamic var hideDisabled = false
    private var blinkTicks = 0
    private var blinkCount = 0
    private var blinkOn = true
    
    override func nextFrame() {
        guard enabled else {
            return
        }
        switch blinkMode {
        case 1:
            // Square-wave
            // blinkValueA = delay between blinks
            // blinkValueB = light on-time
            // blinkValueC = number of blinks in a group
            // blinkValueD = delay between groups
            if blinkCount >= blinkValueC && blinkTicks >= blinkValueD {
                blinkTicks = 0
                blinkCount = 0
            }
            blinkTicks += 1
            if blinkCount < blinkValueC {
                if blinkOn {
                    alpha = 1
                    if blinkTicks >= blinkValueB {
                        blinkOn = false
                        blinkTicks = 0
                    }
                } else {
                    alpha = 0
                    if blinkTicks >= blinkValueA {
                        blinkOn = true
                        blinkTicks = 0
                        blinkCount += 1
                    }
                }
            }
        case 2:
            // Triangle-wave
            // blinkValueA = minimum intensity (1-32)
            // blinkValueB = intensity increase per frame, x100
            // blinkValueC = maximum intensity (1-32)
            // blinkValueD = intensity decrease per frame, x100
            if blinkOn {
                if alpha < CGFloat(min(blinkValueC, 32)) * Self.TransparencyStep {
                    alpha += CGFloat(blinkValueB)/100 * Self.TransparencyStep
                } else {
                    blinkOn = false
                }
            } else {
                if alpha > CGFloat(max(blinkValueA, 0)) * Self.TransparencyStep {
                    alpha -= CGFloat(blinkValueD)/100 * Self.TransparencyStep
                } else {
                    blinkOn = true
                }
            }
        case 3:
            // Random pulsing
            // blinkValueA = minimum intensity (1-32)
            // blinkValueB = maximum intensity (1-32)
            // blinkValueC = delay between intensity changes
            blinkTicks += 1
            if blinkTicks >= blinkValueC {
                // Allow min/max to be swapped if necessary to form a valid range
                let range = (min(blinkValueA, blinkValueB)...max(blinkValueA, blinkValueB)).clamped(to: 0...32)
                alpha = CGFloat(Int16.random(in: range)) * Self.TransparencyStep
                blinkTicks = 0
            }
        default:
            alpha = 1
        }
    }
}
