class ElementLSTB: Element {
    func allowsCreateListEntry() -> Bool {
        return false
    }
    func allowsRemoveListEntry() -> Bool {
        return false
    }
    func createListEntry() {}
    func removeListEntry() {}
}
