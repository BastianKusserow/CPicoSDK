struct FixedOptionalSlots<let count: Int, Element> {
    private var storage = InlineArray<count, Element?>(repeating: nil)

    mutating func insertFirstEmpty(_ element: Element) -> Bool {
        var index = 0
        while index < count {
            if storage[index] == nil {
                storage[index] = element
                return true
            }
            index += 1
        }
        return false
    }

    subscript(index: Int) -> Element? {
        get { storage[index] }
        set { storage[index] = newValue }
    }

    func forEach(_ body: (Element) -> Void) {
        var index = 0
        while index < count {
            if let element = storage[index] {
                body(element)
            }
            index += 1
        }
    }
}

struct RingBuffer<let count: Int, Element> {
    private var storage = InlineArray<count, Element?>(repeating: nil)
    private(set) var head = 0
    private(set) var tail = 0
    private(set) var overflowed = false

    mutating func push(_ element: Element) -> Bool {
        let nextTail = (tail + 1) % count
        if nextTail == head {
            overflowed = true
            return false
        }

        storage[tail] = element
        tail = nextTail
        return true
    }

    mutating func pop() -> Element? {
        guard head != tail else {
            return nil
        }

        let current = head
        head = (head + 1) % count
        let element = storage[current]
        storage[current] = nil
        return element
    }
}
