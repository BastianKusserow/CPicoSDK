import CPicoSDK

@inline(__always)
public func nowMs() -> UInt32 {
    UInt32(time_us_64() / 1000)
}
