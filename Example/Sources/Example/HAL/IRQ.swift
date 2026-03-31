import CPicoSDK

public typealias GPIOIRQHandler = (UInt32, UInt32) -> Void

private let maxIRQHandlers = 8
private let irqQueueCapacity = 32

private struct Handler {
    let pin: UInt32
    let edge: Edge
    let handler: GPIOIRQHandler
}

private nonisolated(unsafe) var irqHandlers = FixedOptionalSlots<8, Handler>()
private nonisolated(unsafe) var irqQueue = RingBuffer<32, (UInt32, UInt32)>()

@inline(__always)
private func withInterruptsDisabled<T>(_ body: () -> T) -> T {
    let state = save_and_disable_interrupts()
    let result = body()
    restore_interrupts(state)
    return result
}

@_cdecl("swift_gpio_irq_callback")
private func swiftGPIOIRQCallback(_ gpio: UInt32, _ events: UInt32) {
    _ = irqQueue.push((gpio, events))
}

private func insertHandler(_ handler: Handler) -> Bool {
    irqHandlers.insertFirstEmpty(handler)
}

private func forEachHandler(_ body: (Handler) -> Void) {
    irqHandlers.forEach(body)
}

@discardableResult
public func gpioOnIRQ(pin: UInt32, edge: Edge, handler: @escaping GPIOIRQHandler) -> Bool {
    let inserted = withInterruptsDisabled {
        insertHandler(Handler(pin: pin, edge: edge, handler: handler))
    }

    guard inserted else {
        print("gpioOnIRQ: no free handler slots, max supported handlers = \(maxIRQHandlers)")
        return false
    }

    gpio_set_irq_enabled_with_callback(pin, edge.picoMask, true, swiftGPIOIRQCallback)
    return true
}

public func pollGPIOIRQs() {
    while true {
        let next = withInterruptsDisabled { irqQueue.pop() }

        guard let (gpio, events) = next else {
            return
        }

        forEachHandler { handler in
            if handler.pin == gpio && (handler.edge.picoMask & events) != 0 {
                handler.handler(gpio, events)
            }
        }
    }
}

public func gpioIRQQueueOverflowed() -> Bool {
    irqQueue.overflowed
}
