import CPicoSDK

public enum Pull {
    case none
    case up
    case down
}

public enum Edge {
    case rising
    case falling
    case both

    var picoMask: UInt32 {
        switch self {
        case .rising: return UInt32(GPIO_IRQ_EDGE_RISE.rawValue)
        case .falling: return UInt32(GPIO_IRQ_EDGE_FALL.rawValue)
        case .both:
            return UInt32(GPIO_IRQ_EDGE_RISE.rawValue) | UInt32(GPIO_IRQ_EDGE_FALL.rawValue)
        }
    }
}

public struct GPIOPin: Sendable {
    public let number: UInt32

    public init(_ number: UInt32) {
        self.number = number
        gpio_init(number)
    }

    public func setDirection(output: Bool) {
        gpio_set_dir(number, output)
    }

    public func write(_ value: Bool) {
        gpio_put(number, value)
    }

    public func read() -> Bool {
        gpio_get(number)
    }

    public func setPull(_ pull: Pull) {
        switch pull {
        case .none:
            gpio_disable_pulls(number)
        case .up:
            gpio_pull_up(number)
        case .down:
            gpio_pull_down(number)
        }
    }

    public func setFunctionPWM() {
        gpio_set_function(number, GPIO_FUNC_PWM)
    }
}
