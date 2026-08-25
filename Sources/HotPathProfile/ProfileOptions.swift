import Darwin

struct BenchmarkOptions {
  let iterations: Int
  let warmup: Int

  fileprivate init(iterations: Int, warmup: Int) {
    self.iterations = iterations
    self.warmup = warmup
  }
}

struct EventPostingOptions {
  let count: Int
  let intervalUsec: UInt32

  fileprivate init(count: Int, intervalUsec: UInt32) {
    self.count = count
    self.intervalUsec = intervalUsec
  }
}

struct ProfileOptions {
  let benchmark: BenchmarkOptions
  let eventPosting: EventPostingOptions?

  private init(benchmark: BenchmarkOptions, eventPosting: EventPostingOptions?) {
    self.benchmark = benchmark
    self.eventPosting = eventPosting
  }

  static func parse(_ commandLine: [String] = CommandLine.arguments) throws -> Self {
    var iterations = 100_000
    var warmup = 10_000
    var postEvents = 0
    var postIntervalUsec: UInt32 = 0
    var arguments = commandLine.dropFirst()

    while let argument = arguments.popFirst() {
      switch argument {
      case "--iterations":
        iterations = try takeInt(&arguments, named: argument, minimum: 1)
      case "--warmup":
        warmup = try takeInt(&arguments, named: argument, minimum: 0)
      case "--post-events":
        postEvents = try takeInt(&arguments, named: argument, minimum: 0)
      case "--post-interval-usec":
        postIntervalUsec = try takeUInt32(&arguments, named: argument)
      case "-h", "--help":
        printHelpAndExit()
      default:
        throw ProfileError("unknown option: \(argument)")
      }
    }

    guard postEvents > 0 || postIntervalUsec == 0 else {
      throw ProfileError("--post-interval-usec requires a positive --post-events value")
    }

    return Self(
      benchmark: BenchmarkOptions(iterations: iterations, warmup: warmup),
      eventPosting: postEvents > 0
        ? EventPostingOptions(count: postEvents, intervalUsec: postIntervalUsec) : nil
    )
  }

  private static func takeInt(
    _ arguments: inout ArraySlice<String>,
    named name: String,
    minimum: Int
  ) throws -> Int {
    guard let rawValue = arguments.popFirst() else {
      throw ProfileError("missing value for \(name)")
    }
    guard let value = Int(rawValue), value >= minimum else {
      throw ProfileError("\(name) must be an integer greater than or equal to \(minimum)")
    }
    return value
  }

  private static func takeUInt32(
    _ arguments: inout ArraySlice<String>, named name: String
  ) throws -> UInt32 {
    guard let rawValue = arguments.popFirst() else {
      throw ProfileError("missing value for \(name)")
    }
    guard let value = UInt32(rawValue) else {
      throw ProfileError("\(name) must be an integer from 0 through \(UInt32.max)")
    }
    return value
  }

  private static func printHelpAndExit() -> Never {
    print(
      """
      usage: HotPathProfile [options]

        --iterations n            measured samples per stage, default 100000
        --warmup n                warmup iterations per stage, default 10000
        --post-events n           post n synthetic scroll events to cgSessionEventTap
        --post-interval-usec n    sleep between posted events
      """
    )
    exit(0)
  }
}

struct ProfileError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}
