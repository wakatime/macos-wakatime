import Foundation

@propertyWrapper
struct Atomic<Value> {
    private var value: Value
    private let lock = NSLock()

    init(wrappedValue value: Value) {
        self.value = value
    }

    var wrappedValue: Value {
      get { getValue() }
      set { setValue(newValue) }
    }

    func getValue() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    mutating func setValue(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
