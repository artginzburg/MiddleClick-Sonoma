import OSLog

@available(macOS, introduced: 10.0, deprecated: 11.0, message: "Use Logger instead")
final class CustomLogger: Sendable {
  private static let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
  private let osLogger: OSLog

  init(category: String) {
    osLogger = OSLog(subsystem: Self.bundleId, category: category)
  }

  /// ## To view logs
  /// ```sh
  /// log stream --predicate 'subsystem == "art.ginzburg.MiddleClick"' --style compact --level info
  /// ```
  func info(_ message: String) {
    os_log("%@", log: osLogger, type: .info, message)
  }

  /// ## To view logs
  /// ```sh
  /// log stream --predicate 'subsystem == "art.ginzburg.MiddleClick"' --style compact
  /// ```
  func error(_ message: String) {
    os_log("%@", log: osLogger, type: .error, message)
  }
}

let log = CustomLogger(category: "app")
let restartLog = CustomLogger(category: "schedule")
