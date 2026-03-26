import CPicoSDK
import CPicoConcurrency
import Synchronization
import PSRAM // Optional, only needed if using PSRAM.

@main
struct App {
    private static let segmentCount = 8
    private static let digitCount = 4
    private static let displayRefreshSliceUs = 1_000
    private static let countdownTickMs = 1_000
    // Segment order must match digitFont bit layout: a b c d e f g dp
    private static let segmentPinValues:
        (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) =
            (5, 9, 19, 17, 16, 6, 20, 18)  // a, b, c, d, e, f, g, dp
    private static let digitPinValues: (UInt32, UInt32, UInt32, UInt32) =
        (4, 7, 8, 21)  // D1 (left) ... D4 (right)
    private static let isCommonAnode = true
    private static let blankPattern: UInt8 = 0

    static func main() {
        stdio_init_all()

        if cyw43_arch_init() != 0 {
            print("CYW43 init failed")
            return
        }
        print("CYW43 init ok")

        configurePins()
        var countdown: Int = 25 * 60
        print("Starting countdown")
        while countdown > 0 {
            renderCountdown(secondsRemaining: countdown, durationMs: countdownTickMs)
            countdown -= 1
        }

        while true {
            renderDigits((0, 0, 0, 0), durationMs: countdownTickMs)
        }
    }

    private static func configurePins() {
        var index = 0
        while index < segmentCount {
            let pin = segmentPin(index)
            gpio_init(pin)
            gpio_set_dir(pin, true)
            gpio_put(pin, levelForSegment(on: false))
            index += 1
        }

        index = 0
        while index < digitCount {
            let pin = digitPin(index)
            gpio_init(pin)
            gpio_set_dir(pin, true)
            gpio_put(pin, levelForDigit(active: false))
            index += 1
        }
    }

    private static func renderCountdown(secondsRemaining: Int, durationMs: Int) {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        renderDigits(
            (
                (minutes / 10) % 10,
                minutes % 10,
                (seconds / 10) % 10,
                seconds % 10
            ),
            durationMs: durationMs
        )
    }

    private static func renderDigits(_ digits: (Int, Int, Int, Int), durationMs: Int) {
        let totalUs = durationMs * 1_000
        var elapsedUs = 0

        while elapsedUs < totalUs {
            renderDigit(digits.0, at: 0)
            renderDigit(digits.1, at: 1)
            renderDigit(digits.2, at: 2)
            renderDigit(digits.3, at: 3)
            elapsedUs += displayRefreshSliceUs * digitCount
        }

        disableAllDigits()
    }

    private static func renderDigit(_ digit: Int, at index: Int) {
        disableAllDigits()
        setSegments(pattern: digitFont(for: digit))
        gpio_put(digitPin(index), levelForDigit(active: true))
        sleep_us(UInt64(displayRefreshSliceUs))
        gpio_put(digitPin(index), levelForDigit(active: false))
    }

    private static func setSegments(pattern: UInt8) {
        var index = 0
        while index < segmentCount {
            let isOn = (pattern & (1 << index)) != 0
            gpio_put(segmentPin(index), levelForSegment(on: isOn))
            index += 1
        }
    }

    private static func digitFont(for digit: Int) -> UInt8 {
        switch digit {
        case 0: return 0b00111111
        case 1: return 0b00000110
        case 2: return 0b01011011
        case 3: return 0b01001111
        case 4: return 0b01100110
        case 5: return 0b01101101
        case 6: return 0b01111101
        case 7: return 0b00000111
        case 8: return 0b01111111
        case 9: return 0b01101111
        default: return blankPattern
        }
    }

    private static func segmentPin(_ index: Int) -> UInt32 {
        switch index {
        case 0: return segmentPinValues.0
        case 1: return segmentPinValues.1
        case 2: return segmentPinValues.2
        case 3: return segmentPinValues.3
        case 4: return segmentPinValues.4
        case 5: return segmentPinValues.5
        case 6: return segmentPinValues.6
        default: return segmentPinValues.7
        }
    }

    private static func digitPin(_ index: Int) -> UInt32 {
        switch index {
        case 0: return digitPinValues.0
        case 1: return digitPinValues.1
        case 2: return digitPinValues.2
        case 3: return digitPinValues.3
        default: return digitPinValues.3
        }
    }

    private static func disableAllDigits() {
        var index = 0
        while index < digitCount {
            gpio_put(digitPin(index), levelForDigit(active: false))
            index += 1
        }
    }

    private static func levelForSegment(on: Bool) -> Bool {
        isCommonAnode ? !on : on
    }

    private static func levelForDigit(active: Bool) -> Bool {
        isCommonAnode ? active : !active
    }
}

// MARK: LED Example

func blinkLeds() async throws(CancellationError) {
    var last_state: Bool = false

    while true {
        status_led_set_state(last_state)
        last_state = !last_state
        try await Task.sleep(ms: 100)
    }
}

@c
func ledExample() {
    var last_state = false

    while true {
        status_led_set_state(last_state)
        last_state = !last_state

        // In async contexts this is discouraged, as sleep_ms will
        // block the entire async context. This example works fine
        // when not using or expecting to use Concurrency features.
        sleep_ms(100)

        Task.tightLoop()
    }
}

// MARK: PIO Example

enum PIOError: Error {
    case noFreeStateMachine
    case pioNotResolved
}

// This is a reimplementation of hello_pio from pico-examples
// https://github.com/raspberrypi/pico-examples/blob/master/pio/hello_pio/hello.c
func pioExample() throws(PIOError) {
    // Note that this is not the LED pin, we will blink on GPIO 20 for this example.
    // Please connect something visible to see the effect!
    let pin: UInt32 = 20

    var pio: PIO?
    let sm: UInt32 = 0
    var offset: UInt32 = 0

    // ------------------------------------------------------
    // Option 1: Claim a free state machine and load the program automatically
    // ------------------------------------------------------

    // // This will find a free pio and state machine for our program and load it for us
    // // We use pio_claim_free_sm_and_add_program_for_gpio_range so we can address gpios >= 32 if needed and supported by the hardware
    // guard pio_claim_free_sm_and_add_program_for_gpio_range(hello.program, &pio, &sm, &offset, pin, 1, true) else {
    //     throw PIOError.noFreeStateMachine
    // }

    // guard let pio = pio else {
    //     throw PIOError.pioNotResolved
    // }

    // ------------------------------------------------------
    // Option 2: Manually use a specific PIO and state machine
    // ------------------------------------------------------

    // This is the manual way of doing the same as above
    pio = pio0
    guard let pio = pio else {
        throw PIOError.pioNotResolved
    }

    guard let newOffset = UInt32(exactly: pio_add_program(pio, hello.program)) else {
        throw PIOError.noFreeStateMachine
    }
    offset = newOffset

    // ------------------------------------------------------

    print("Loaded program at \(offset)")

    // Configure it to run our program, and start it, using the
    // helper function we included in our .pio file.
    hello.program_init(pio: pio, sm: sm, offset: offset, pin: pin)

    // The state machine is now running. Any value we push to its TX FIFO will
    // appear on the pin.
    // press a key to exit
    while getchar_timeout_us(0) == PICO_ERROR_TIMEOUT.rawValue {
        // Blink
        pio_sm_put_blocking(pio, sm, 1)
        sleep_ms(500)
        // Blonk
        pio_sm_put_blocking(pio, sm, 0)
        sleep_ms(500)
    }

    print("Pin \(pin) will stop blinking now.")

    // This will free resources and unload our program
    pio_remove_program_and_unclaim_sm(hello.program, pio, sm, offset)
}

struct Foo {
    @TaskLocal
    static var bar: String?

    func getBar() -> String {
        return Foo.bar ?? "no bar"
    }
}
