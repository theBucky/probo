import Foundation

struct TestCase: Sendable {
  let behavior: String
  let body: @Sendable () throws -> Void
}

struct TestFailure: Error, CustomStringConvertible {
  let description: String
}

func fail(_ message: String) throws -> Never {
  throw TestFailure(description: message)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if condition() {
    return
  }
  try fail(message)
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
  if actual == expected {
    return
  }
  try fail("\(message): expected \(expected), got \(actual)")
}

func expectNil<T>(_ actual: T?, _ message: String) throws {
  if actual == nil {
    return
  }
  try fail(message)
}

func expectNotNil<T>(_ actual: T?, _ message: String) throws -> T {
  if let actual {
    return actual
  }
  try fail(message)
}

@main
enum ProboTests {
  static func main() {
    let tests = scrollRewriteCoreTests + scrollEventSynthesizerTests + appConfigurationStoreTests
    var failures = 0

    for test in tests {
      do {
        try test.body()
        print("[green] \(test.behavior)")
      } catch {
        failures += 1
        print("[red] \(test.behavior)")
        print("  \(error)")
      }
    }

    if failures == 0 {
      print("[green] \(tests.count) tests passed")
      return
    }

    print("[red] \(failures) of \(tests.count) tests failed")
    exit(1)
  }
}
