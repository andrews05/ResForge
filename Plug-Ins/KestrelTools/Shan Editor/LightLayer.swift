import Cocoa

class LightLayer: SpriteLayer {
    @objc dynamic var blinkMode: Int16 = 0
    @objc dynamic var blinkValueA: Int16 = 0
    @objc dynamic var blinkValueB: Int16 = 0
    @objc dynamic var blinkValueC: Int16 = 0
    @objc dynamic var blinkValueD: Int16 = 0
    private var blinkFrame = 0
    private var blinkCount = 0
    private var blinkOn = true
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.lightSprite
        blinkMode = shan.blinkMode
        blinkValueA = shan.blinkValueA
        blinkValueB = shan.blinkValueB
        blinkValueC = shan.blinkValueC
        blinkValueD = shan.blinkValueD
    }
    
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
            alpha = 0
            if blinkCount >= blinkValueC && blinkFrame >= blinkValueD {
                blinkFrame = 0
                blinkCount = 0
            }
            blinkFrame += 1
            if blinkCount < blinkValueC {
                if blinkOn {
                    alpha = 1
                    if blinkFrame >= blinkValueB {
                        blinkFrame = 0
                        blinkOn = false
                    }
                } else {
                    if blinkFrame >= blinkValueA {
                        blinkFrame = 0
                        blinkCount += 1
                        blinkOn = true
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
                if alpha < CGFloat(min(blinkValueC, 32)-1) / 31 {
                    alpha += CGFloat(blinkValueB)/100/32
                } else {
                    blinkOn = false
                }
            } else {
                if alpha > CGFloat(max(blinkValueA, 1)-1) / 31 {
                    alpha -= CGFloat(blinkValueD)/100/32
                } else {
                    blinkOn = true
                }
            }
        case 3:
            // Random pulsing
            // blinkValueA = minimum intensity (1-32)
            // blinkValueB = maximum intensity (1-32)
            // blinkValueC = delay between intensity changes
            blinkFrame += 1
            if blinkFrame >= blinkValueC {
                let minVal = max(min(blinkValueA, blinkValueB), 1)
                let maxVal = min(max(blinkValueA, blinkValueB), 32)
                alpha = CGFloat(Int16.random(in: minVal...maxVal)-1) / 31
                blinkFrame = 0
            }
        default:
            alpha = 1
        }
    }
}
