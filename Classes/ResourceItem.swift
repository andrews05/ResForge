import Cocoa

class ResourceItem: NSCollectionViewItem {
    @IBOutlet var imageBox: NSBox!
    @IBOutlet var textBox: NSBox!
    
    override var isSelected: Bool {
        didSet {
            self.highlight(isSelected)
        }
    }
    
    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            if !isSelected || highlightState == .forDeselection {
                self.highlight(highlightState == .forSelection)
            }
        }
    }
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        let clicker = NSClickGestureRecognizer(target: self, action: #selector(doubleClick))
//        clicker.numberOfClicksRequired = 2
//        clicker.delaysPrimaryMouseButtonEvents = false
//        self.view.addGestureRecognizer(clicker)
//    }
    
    private func highlight(_ on: Bool) {
        imageBox.isTransparent = !on
        textBox.isTransparent = !on
        textField?.textColor = on ? .alternateSelectedControlTextColor : .controlTextColor
    }
    
    @objc private func doubleClick() {
        let document = self.view.window!.delegate as! ResourceDocument
        document.openResources(self)
    }
}
