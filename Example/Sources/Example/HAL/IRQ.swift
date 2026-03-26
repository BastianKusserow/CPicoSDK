import CPicoSDK

public typealias GPIOIRQHandler = (UInt32, UInt32) -> Void

@_silgen_name("register_swift_gpio_irq_callback")
public func register_swift_gpio_irq_callback(_ gpio: UInt32, _ events: UInt32, _ enabled: Bool)

@_silgen_name("swift_save_and_disable_interrupts")
private func swift_save_and_disable_interrupts() -> UInt32

@_silgen_name("swift_restore_interrupts")
private func swift_restore_interrupts(_ status: UInt32)

@_silgen_name("swift_gpio_irq_pop")
private func swift_gpio_irq_pop(_ gpio: UnsafeMutablePointer<UInt32>, _ events: UnsafeMutablePointer<UInt32>) -> Bool

@_silgen_name("swift_gpio_irq_queue_overflowed")
private func swift_gpio_irq_queue_overflowed() -> Bool

@inline(__always)
private func withInterruptsDisabled<T>(_ body: () -> T) -> T {
    let state = swift_save_and_disable_interrupts()
    let result = body()
    swift_restore_interrupts(state)
    return result
}

private let maxIRQHandlers = 4
private nonisolated(unsafe) var irqHandlers: (Handler?, Handler?, Handler?, Handler?) = (nil, nil, nil, nil)

private func insertHandler(_ handler: Handler) -> Bool {
    if irqHandlers.0 == nil {
        irqHandlers.0 = handler
        return true
    }
    if irqHandlers.1 == nil {
        irqHandlers.1 = handler
        return true
    }
    if irqHandlers.2 == nil {
        irqHandlers.2 = handler
        return true
    }
    if irqHandlers.3 == nil {
        irqHandlers.3 = handler
        return true
    }
    return false
}

private func forEachHandler(_ body: (Handler) -> Void) {
    if let h = irqHandlers.0 { body(h) }
    if let h = irqHandlers.1 { body(h) }
    if let h = irqHandlers.2 { body(h) }
    if let h = irqHandlers.3 { body(h) }
}

@discardableResult
public func gpioOnIRQ(pin: UInt32, edge: Edge, handler: @escaping GPIOIRQHandler) -> Bool {
    let inserted = withInterruptsDisabled {
        let handler = Handler(pin: pin, edge: edge, handler: handler)
        return insertHandler(handler)
    }

    guard inserted else {
        print("gpioOnIRQ: no free handler slots, max supported handlers = \(maxIRQHandlers)")
        return false
    }

    register_swift_gpio_irq_callback(pin, edge.picoMask, true)
    return true
}

public func pollGPIOIRQs() {
    var gpio: UInt32 = 0
    var events: UInt32 = 0
    while swift_gpio_irq_pop(&gpio, &events) {
        forEachHandler { h in
            if h.pin == gpio && (h.edge.picoMask & events) != 0 {
                h.handler(gpio, events)
            }
        }
    }
}

public func gpioIRQQueueOverflowed() -> Bool {
    swift_gpio_irq_queue_overflowed()
}

struct Handler {
    let pin: UInt32
    let edge: Edge
    let handler: GPIOIRQHandler
}
