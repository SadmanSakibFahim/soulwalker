import CoreMotion
import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var motionBridge: MotionBridge?
  private var healthBridge: HealthBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    motionBridge = MotionBridge(messenger: messenger)
    healthBridge = HealthBridge(messenger: messenger)
  }
}

/// Reads walking distance from the motion coprocessor. The history survives
/// the app being locked or suspended, so a pocket walk can be banked on resume.
final class MotionBridge: NSObject {
  private let pedometer = CMPedometer()
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "soulwalker/motion", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      let ready = CMPedometer.isDistanceAvailable() || CMPedometer.isStepCountingAvailable()
      result(ready)
    case "read":
      read(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func read(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let startMs = args["startMs"] as? NSNumber
    else {
      result(FlutterError(code: "bad_args", message: "startMs required", details: nil))
      return
    }
    guard CMPedometer.isStepCountingAvailable() else {
      result(
        FlutterError(
          code: "unavailable",
          message: "This phone cannot count a walk. Use a physical iPhone.",
          details: nil
        )
      )
      return
    }
    let start = Date(timeIntervalSince1970: startMs.doubleValue / 1000.0)
    let end = Date()
    if end <= start {
      result(["distanceMeters": 0])
      return
    }
    pedometer.queryPedometerData(from: start, to: end) { data, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "query_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        var payload: [String: Any] = [:]
        if CMPedometer.isDistanceAvailable(), let meters = data?.distance?.doubleValue {
          payload["distanceMeters"] = Int(meters.rounded())
        } else if let steps = data?.numberOfSteps.intValue {
          payload["stepCount"] = steps
        }
        result(payload)
      }
    }
  }
}

/// Reads step count and walking distance that Apple Health already stored.
final class HealthBridge: NSObject {
  private let store = HKHealthStore()
  private let channel: FlutterMethodChannel
  private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "soulwalker/health", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      result(HKHealthStore.isHealthDataAvailable())
    case "requestAccess":
      requestAccess(result: result)
    case "readDays":
      readDays(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readTypes() -> Set<HKObjectType>? {
    guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
          let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
    else {
      return nil
    }
    return [steps, distance]
  }

  private func requestAccess(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(), let types = readTypes() else {
      result(false)
      return
    }
    store.requestAuthorization(toShare: nil, read: types) { success, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "auth_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(success)
      }
    }
  }

  private func readDays(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(
        FlutterError(
          code: "unavailable",
          message: "Apple Health is not on this device. Use a physical iPhone.",
          details: nil
        )
      )
      return
    }
    guard let args = call.arguments as? [String: Any],
          let rawDates = args["dates"] as? [String]
    else {
      result(FlutterError(code: "bad_args", message: "dates required", details: nil))
      return
    }
    let calendar = Calendar.current
    var starts: [Date] = []
    for raw in rawDates {
      guard let parsed = dayFormatter.date(from: raw) else {
        result(FlutterError(code: "bad_date", message: "Unreadable day \(raw)", details: nil))
        return
      }
      starts.append(calendar.startOfDay(for: parsed))
    }
    guard let first = starts.min(), let last = starts.max(),
          let end = calendar.date(byAdding: .day, value: 1, to: last),
          let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
          let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
    else {
      result(["days": []])
      return
    }

    let group = DispatchGroup()
    let lock = DispatchQueue(label: "soulwalker.health")
    var distances: [String: Int] = [:]
    var steps: [String: Int] = [:]
    var failure: String?

    group.enter()
    collect(type: distanceType, unit: .meter(), from: first, to: end) { sums, error in
      lock.async {
        if let error {
          failure = error
        } else {
          distances = sums
        }
        group.leave()
      }
    }
    group.enter()
    collect(type: stepsType, unit: .count(), from: first, to: end) { sums, error in
      lock.async {
        if let error {
          failure = error
        } else {
          steps = sums
        }
        group.leave()
      }
    }

    group.notify(queue: lock) {
      let message = failure
      let distanceCopy = distances
      let stepCopy = steps
      DispatchQueue.main.async {
        if let message {
          result(FlutterError(code: "query_failed", message: message, details: nil))
          return
        }
        var days: [[String: Any]] = []
        for start in starts {
          let key = self.dayFormatter.string(from: start)
          var row: [String: Any] = ["date": key]
          if let meters = distanceCopy[key] {
            row["distanceMeters"] = meters
          }
          if let count = stepCopy[key] {
            row["stepCount"] = count
          }
          days.append(row)
        }
        result(["days": days])
      }
    }
  }

  private func collect(
    type: HKQuantityType,
    unit: HKUnit,
    from start: Date,
    to end: Date,
    done: @escaping ([String: Int], String?) -> Void
  ) {
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: nil,
      options: .cumulativeSum,
      anchorDate: start,
      intervalComponents: DateComponents(day: 1)
    )
    query.initialResultsHandler = { _, results, error in
      if let error {
        done([:], error.localizedDescription)
        return
      }
      let formatter = DateFormatter()
      formatter.calendar = Calendar.current
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      formatter.dateFormat = "yyyy-MM-dd"
      var sums: [String: Int] = [:]
      results?.enumerateStatistics(from: start, to: end) { stats, _ in
        let key = formatter.string(from: stats.startDate)
        if let quantity = stats.sumQuantity() {
          sums[key] = Int(quantity.doubleValue(for: unit).rounded())
        }
      }
      done(sums, nil)
    }
    store.execute(query)
  }
}
