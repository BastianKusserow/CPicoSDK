import CPicoSDK

public final class PWMChannel {
    private let gpio: UInt32
    private let slice: UInt32
    private let channel: UInt32

    private let pwmClockHz: Float = 125_000_000
    private var wrap: UInt16 = 1000

    public init(gpio: UInt32) {
        self.gpio = gpio
        self.slice = pwm_gpio_to_slice_num(gpio)
        self.channel = pwm_gpio_to_channel(gpio)

        gpio_set_function(gpio, GPIO_FUNC_PWM)
        pwm_set_enabled(slice, false)
    }

    public func setEnabled(_ enabled: Bool) {
        pwm_set_enabled(slice, enabled)
    }

    public func setFrequency(_ hz: UInt32) {
        let targetHz = max(1, hz)
        pwm_set_wrap(slice, wrap)

        let topPlus1 = Float(wrap) + 1.0
        let div = pwmClockHz / (Float(targetHz) * topPlus1)
        // Clamp to reasonable range for RP2040 (clkdiv is 1..255-ish)
        let clamped = min(max(div, 1.0), 255.0)
        pwm_set_clkdiv(slice, clamped)
    }

    /// duty16: 0..65535
    public func setDuty16(_ duty16: UInt16) {
        // Map duty16 to 0..wrap
        let level = UInt16((UInt32(duty16) * UInt32(wrap)) / 65535)
        pwm_set_chan_level(slice, channel, level)
    }
}
