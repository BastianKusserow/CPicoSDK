# Runtime TODO

## Replace Closure Queue With Typed Events

The current runtime scheduler in
[Example/Sources/Example/HAL/Runtime.swift](/Users/bastian.kusserow/Developer/Personal/SwiftEmbedded/CPicoSDK/Example/Sources/Example/HAL/Runtime.swift)
stores deferred work as closures. That is fine for the first iteration, but it is
not the most predictable embedded design.

### Why change it

- Closures capture state, which makes memory behavior and lifetimes less explicit.
- IRQ handoff is easier to reason about when the queue contains plain data values.
- Typed events are easier to debug and inspect in logs.

### Preferred direction

Replace the closure queue with a fixed-capacity event/command queue, for example:

```swift
enum RuntimeEvent {
    case rotaryChanged(change: RotaryChange)
    case switchChanged(pressed: Bool)
}
```

Then the flow becomes:

1. GPIO IRQ callback enqueues a `RuntimeEvent`
2. `Runtime.service()` drains the event queue
3. A dispatcher routes the event to the correct handler list

### Follow-up work

- Add a fixed-capacity `InlineArray` event queue to `Runtime`
- Add a `RuntimeEvent` dispatcher
- Update `RotaryEncoder` to enqueue typed events instead of closures
- Consider adding lightweight logging for queue overflow
