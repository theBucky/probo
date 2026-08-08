import Darwin

struct ProfileOptions {
  var iterations = 100_000
  var warmup = 10_000
  var postEvents = 0
  var postIntervalUsec: UInt32 = 0

  static func parse(_ commandLine: [String] = CommandLine.arguments) throws -> Self {
    var options = Self()
    var arguments = commandLine.dropFirst()

    while let argument = arguments.popFirst() {
      switch argument {
      case "--iterations":
        options.iterations = try takeInt(
          &arguments,
          named: argument,
          in: 1...Int.max,
          requirement: "a positive integer"
        )
      case "--warmup":
        options.warmup = try takeInt(
          &arguments,
          named: argument,
          in: 0...Int.max,
          requirement: "a non-negative integer"
        )
      case "--post-events":
        options.postEvents = try takeInt(
          &arguments,
          named: argument,
          in: 0...Int.max,
          requirement: "a non-negative integer"
        )
      case "--post-interval-usec":
        options.postIntervalUsec = try takeUInt32(&arguments, named: argument)
      case "-h", "--help":
        printHelpAndExit()
      default:
        throw ProfileError("unknown option: \(argument)")
      }
    }

    return options
  }

  private static func takeInt(
    _ arguments: inout ArraySlice<String>,
    named name: String,
    in validRange: ClosedRange<Int>,
    requirement: String
  ) throws -> Int {
    guard let rawValue = arguments.popFirst() else {
      throw ProfileError("missing value for \(name)")
    }
    guard let value = Int(rawValue), validRange.contains(value) else {
      throw ProfileError("\(name) must be \(requirement)")
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
