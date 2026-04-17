import Flutter
import HealthKit
import UIKit

public class VisitFlutterSdkPlugin: NSObject, FlutterPlugin {
  private enum HealthConnectResponse: String {
    case cancelled = "CANCELLED"
    case connected = "CONNECTED"
    case granted = "GRANTED"
    case installed = "INSTALLED"
    case notSupported = "NOT_SUPPORTED"
  }

  private enum StoredKey {
    static let apiBaseUrl = "visit_flutter_sdk.apiBaseUrl"
    static let authToken = "visit_flutter_sdk.authToken"
    static let dailyLastSync = "visit_flutter_sdk.googleFitLastSync"
    static let hourlyLastSync = "visit_flutter_sdk.gfHourlyLastSync"
  }

  private let healthStore = HKHealthStore()
  private let defaults = UserDefaults.standard
  private lazy var calendar: Calendar = {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .current
    return calendar
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "visit_flutter_sdk",
      binaryMessenger: registrar.messenger()
    )
    let instance = VisitFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getHealthConnectStatus":
      getHealthConnectStatus(result)
    case "askForFitnessPermission":
      askForFitnessPermission(result)
    case "requestDailyFitnessData":
      requestDailyFitnessData(result)
    case "requestActivityDataFromHealthConnect":
      requestActivityData(from: call, result: result)
    case "updateApiBaseUrl":
      updateApiBaseUrl(from: call, result: result)
    case "openHealthConnectApp":
      result(nil)
    case "fetchHourlyData":
      fetchHourlyData(from: call, result: result)
    case "fetchDailyData":
      fetchDailyData(from: call, result: result)
    case "triggerManualSync":
      triggerManualSync()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getHealthConnectStatus(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(), let stepType = stepCountType else {
      result(HealthConnectResponse.notSupported.rawValue)
      return
    }

    let authorizationStatus = healthStore.authorizationStatus(for: stepType)
    result(
      authorizationStatus == .sharingAuthorized
        ? HealthConnectResponse.connected.rawValue
        : HealthConnectResponse.installed.rawValue
    )
  }

  private func askForFitnessPermission(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(HealthConnectResponse.notSupported.rawValue)
      return
    }

    if hasHealthAuthorization {
      result(HealthConnectResponse.granted.rawValue)
      return
    }

    healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, _ in
      DispatchQueue.main.async {
        result(success ? HealthConnectResponse.granted.rawValue : HealthConnectResponse.cancelled.rawValue)
      }
    }
  }

  private func requestDailyFitnessData(_ result: @escaping FlutterResult) {
    guard hasHealthAuthorization else {
      result("window.updateFitnessPermissions(false,0,0)")
      return
    }

    let group = DispatchGroup()
    var steps = 0
    var sleepMinutes = 0

    group.enter()
    fetchStepCount(for: Date(), frequency: "day", days: 1) { stepSeries, _ in
      steps = stepSeries.first ?? 0
      group.leave()
    }

    group.enter()
    fetchSleepSamples(for: Date(), frequency: "day", days: 1) { samples in
      sleepMinutes = samples.reduce(0) { partialResult, sample in
        guard let value = sample["value"] as? String,
          value == "INBED" || value == "ASLEEP",
          let startDate = sample["startDate"] as? Date,
          let endDate = sample["endDate"] as? Date
        else {
          return partialResult
        }

        return partialResult + Int(endDate.timeIntervalSince(startDate) / 60)
      }
      group.leave()
    }

    group.notify(queue: .main) {
      result("window.updateFitnessPermissions(true,\(steps),\(sleepMinutes))")
    }
  }

  private func requestActivityData(from call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard hasHealthAuthorization else {
      result(nil)
      return
    }

    guard let arguments = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Expected requestActivityDataFromHealthConnect arguments.",
          details: nil
        )
      )
      return
    }

    let type = (arguments["type"] as? String) ?? ""
    let frequency = (arguments["frequency"] as? String) ?? ""
    let timestamp = (arguments["timestamp"] as? NSNumber)?.doubleValue
      ?? (arguments["timestamp"] as? Double)
      ?? Double((arguments["timestamp"] as? Int64) ?? 0)
    let date = Date(timeIntervalSince1970: timestamp / 1000)

    renderGraphData(type: type, frequency: frequency, date: date, result: result)
  }

  private func updateApiBaseUrl(from call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Expected updateApiBaseUrl arguments.",
          details: nil
        )
      )
      return
    }

    defaults.set(arguments["apiBaseUrl"] as? String ?? "", forKey: StoredKey.apiBaseUrl)
    defaults.set(arguments["authtoken"] as? String ?? "", forKey: StoredKey.authToken)
    defaults.set(int64Value(for: arguments["googleFitLastSync"]), forKey: StoredKey.dailyLastSync)
    defaults.set(int64Value(for: arguments["gfHourlyLastSync"]), forKey: StoredKey.hourlyLastSync)

    result("Health sync configuration updated")
  }

  private func fetchHourlyData(from call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard hasHealthAuthorization else {
      result(
        FlutterError(code: "healthkit_unavailable", message: "HealthKit permission is not granted.", details: nil)
      )
      return
    }

    let timestamp = timestampValue(from: call.arguments)
    let date = Date(timeIntervalSince1970: timestamp / 1000)
    let group = DispatchGroup()
    var steps: [Int] = []
    var calories: [Int] = []
    var distance: [Int] = []

    group.enter()
    fetchHourlySteps(for: date) { hourlySteps, hourlyCalories in
      steps = hourlySteps
      calories = hourlyCalories
      group.leave()
    }

    group.enter()
    fetchHourlyDistanceWalkingRunning(for: date) { hourlyDistance in
      distance = hourlyDistance
      group.leave()
    }

    group.notify(queue: .main) {
      result(self.preprocessEmbellishRequest(steps: steps, calories: calories, distance: distance, date: date))
    }
  }

  private func fetchDailyData(from call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard hasHealthAuthorization else {
      result(
        FlutterError(code: "healthkit_unavailable", message: "HealthKit permission is not granted.", details: nil)
      )
      return
    }

    let timestamp = timestampValue(from: call.arguments)
    let startDate = Date(timeIntervalSince1970: timestamp / 1000)
    let dates = getDateRanges(from: startDate)

    guard !dates.isEmpty else {
      result([])
      return
    }

    callSyncData(days: dates.count, dates: dates, result: result)
  }

  private func triggerManualSync() {
    let _ = defaults.string(forKey: StoredKey.apiBaseUrl) ?? ""
    let _ = defaults.string(forKey: StoredKey.authToken) ?? ""
    let _ = defaults.double(forKey: StoredKey.hourlyLastSync)
    let _ = defaults.double(forKey: StoredKey.dailyLastSync)
  }

  private func renderGraphData(type: String, frequency: String, date: Date, result: @escaping FlutterResult) {
    switch type {
    case "steps", "calories", "distance":
      let group = DispatchGroup()
      var stepsOrDistance: [Int] = []
      var calories: [Int] = []
      var totalActivityDuration = "0.000000"

      group.enter()
      fetchActivityDurations(for: date, frequency: frequency, days: 1) { totalMinutes, _ in
        totalActivityDuration = String(format: "%.6f", totalMinutes)
        group.leave()
      }

      group.enter()
      if type == "distance" {
        if frequency == "day" {
          fetchHourlyDistanceWalkingRunning(for: date) { data in
            stepsOrDistance = data
            group.leave()
          }
        } else {
          fetchDistanceWalkingRunning(for: date, frequency: frequency, days: 1) { data in
            stepsOrDistance = data
            group.leave()
          }
        }
      } else if frequency == "day" {
        fetchHourlySteps(for: date) { steps, hourlyCalories in
          stepsOrDistance = steps
          calories = hourlyCalories
          group.leave()
        }
      } else {
        fetchStepCount(for: date, frequency: frequency, days: 1) { data, calorieData in
          stepsOrDistance = data
          calories = calorieData
          group.leave()
        }
      }

      group.notify(queue: .main) {
        let selectedData = type == "calories" ? calories : stepsOrDistance
        result(
          self.evaluateJavascript(
            data: selectedData,
            type: type,
            frequency: frequency,
            activityTime: totalActivityDuration
          )
        )
      }
    case "sleep":
      renderSleepGraphData(frequency: frequency, date: date, result: result)
    default:
      result(nil)
    }
  }

  private func renderSleepGraphData(frequency: String, date: Date, result: @escaping FlutterResult) {
    fetchSleepSamples(for: date, frequency: frequency, days: 1) { samples in
      if frequency == "day" {
        var sleepTime: Int64 = 0
        var wakeTime: Int64 = 0

        for sample in samples {
          guard let value = sample["value"] as? String,
            value == "INBED" || value == "ASLEEP",
            let startDate = sample["startDate"] as? Date,
            let endDate = sample["endDate"] as? Date
          else {
            continue
          }

          if sleepTime == 0 {
            sleepTime = self.millisecondsSince1970(startDate)
          }

          wakeTime = self.millisecondsSince1970(endDate)
        }

        result("DetailedGraph.updateDailySleep(\(sleepTime),\(wakeTime))")
        return
      }

      let groupedSleep = self.groupSleepSamplesByDay(samples)
      let normalizedSleep = self.padSleepDataIfNeeded(groupedSleep)
      let jsonData = self.jsonString(from: normalizedSleep)
      result("DetailedGraph.updateSleepData(JSON.stringify(\(jsonData)))")
    }
  }

  private func fetchHourlySteps(for date: Date, completion: @escaping ([Int], [Int]) -> Void) {
    guard let stepCountType = stepCountType else {
      completion([], [])
      return
    }

    let startDate = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDate) ?? date
    let interval = DateComponents(hour: 1)
    let predicate = activityPredicate(startDate: startDate, endDate: endOfDay)
    let query = HKStatisticsCollectionQuery(
      quantityType: stepCountType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum,
      anchorDate: startDate,
      intervalComponents: interval
    )

    query.initialResultsHandler = { [weak self] _, result, _ in
      guard let self, let result else {
        completion([], [])
        return
      }

      let bmrCaloriesPerHour = self.currentBmrCaloriesPerHour()
      var stepsData: [Int] = []
      var calorieData: [Int] = []

      result.enumerateStatistics(from: startDate, to: endOfDay) { statistics, _ in
        let value = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
        stepsData.append(value)
        calorieData.append(value == 0 ? 0 : (value / 21) + bmrCaloriesPerHour)
      }

      completion(stepsData, calorieData)
    }

    healthStore.execute(query)
  }

  private func fetchStepCount(
    for endDate: Date,
    frequency: String,
    days: Int,
    completion: @escaping ([Int], [Int]) -> Void
  ) {
    guard let stepCountType = stepCountType, let range = dateRange(for: endDate, frequency: frequency, days: days) else {
      completion([], [])
      return
    }

    let query = HKStatisticsCollectionQuery(
      quantityType: stepCountType,
      quantitySamplePredicate: nil,
      options: .cumulativeSum,
      anchorDate: calendar.startOfDay(for: range.start),
      intervalComponents: DateComponents(day: 1)
    )

    query.initialResultsHandler = { [weak self] _, result, _ in
      guard let self, let result else {
        completion([], [])
        return
      }

      let bmrCaloriesPerHour = self.currentBmrCaloriesPerHour()
      var data: [Int] = []
      var calorieData: [Int] = []

      result.enumerateStatistics(from: range.start, to: range.end) { statistics, _ in
        let value = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
        data.append(value)
        calorieData.append(value == 0 ? 0 : (value / 21) + bmrCaloriesPerHour)
      }

      completion(data, calorieData)
    }

    healthStore.execute(query)
  }

  private func fetchHourlyDistanceWalkingRunning(for date: Date, completion: @escaping ([Int]) -> Void) {
    guard let distanceType = distanceWalkingRunningType else {
      completion([])
      return
    }

    let startDate = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDate) ?? date
    let predicate = activityPredicate(startDate: startDate, endDate: endOfDay)
    let query = HKStatisticsCollectionQuery(
      quantityType: distanceType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum,
      anchorDate: startDate,
      intervalComponents: DateComponents(hour: 1)
    )

    query.initialResultsHandler = { _, result, _ in
      guard let result else {
        completion([])
        return
      }

      var data: [Int] = []
      result.enumerateStatistics(from: startDate, to: endOfDay) { statistics, _ in
        let value = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0)
        data.append(value)
      }

      completion(data)
    }

    healthStore.execute(query)
  }

  private func fetchDistanceWalkingRunning(
    for endDate: Date,
    frequency: String,
    days: Int,
    completion: @escaping ([Int]) -> Void
  ) {
    guard let distanceType = distanceWalkingRunningType,
      let range = dateRange(for: endDate, frequency: frequency, days: days)
    else {
      completion([])
      return
    }

    let query = HKStatisticsCollectionQuery(
      quantityType: distanceType,
      quantitySamplePredicate: nil,
      options: .cumulativeSum,
      anchorDate: calendar.startOfDay(for: range.start),
      intervalComponents: DateComponents(day: 1)
    )

    query.initialResultsHandler = { _, result, _ in
      guard let result else {
        completion([])
        return
      }

      var data: [Int] = []
      result.enumerateStatistics(from: range.start, to: range.end) { statistics, _ in
        let value = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0)
        data.append(value)
      }

      completion(data)
    }

    healthStore.execute(query)
  }

  private func fetchActivityDurations(
    for endDate: Date,
    frequency: String,
    days: Int,
    completion: @escaping (Double, [[String: Any]]) -> Void
  ) {
    guard let stepCountType = stepCountType,
      let range = dateRange(for: endDate, frequency: frequency, days: days)
    else {
      completion(0, [])
      return
    }

    let query = HKSampleQuery(
      sampleType: stepCountType,
      predicate: activityPredicate(startDate: range.start, endDate: range.end),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
    ) { [weak self] _, results, _ in
      guard let self else {
        completion(0, [])
        return
      }

      var totalMinutes = 0.0
      var groupedMinutesByDay: [Int64: Double] = [:]
      var groupedDatesByDay: [Int64: Date] = [:]

      for case let sample as HKQuantitySample in results ?? [] {
        let value = sample.quantity.doubleValue(for: HKUnit.count())
        guard value > 0 else { continue }

        let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
        totalMinutes += durationMinutes

        let dayStart = self.calendar.startOfDay(for: sample.endDate)
        let dayKey = self.millisecondsSince1970(dayStart)
        groupedMinutesByDay[dayKey, default: 0] += durationMinutes
        groupedDatesByDay[dayKey] = sample.endDate
      }

      let groupedData = groupedMinutesByDay.keys.sorted().compactMap { key -> [String: Any]? in
        guard let date = groupedDatesByDay[key], let value = groupedMinutesByDay[key] else {
          return nil
        }

        return [
          "date": date,
          "value": value
        ]
      }

      completion(totalMinutes, groupedData)
    }

    healthStore.execute(query)
  }

  private func fetchSleepSamples(
    for endDate: Date,
    frequency: String,
    days: Int,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    guard let sleepType = sleepAnalysisType,
      let range = sleepDateRange(for: endDate, frequency: frequency, days: days)
    else {
      completion([])
      return
    }

    let query = HKSampleQuery(
      sampleType: sleepType,
      predicate: HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
    ) { [weak self] _, results, _ in
      guard let self else {
        completion([])
        return
      }

      let data = (results ?? []).compactMap { sample -> [String: Any]? in
        guard let categorySample = sample as? HKCategorySample else {
          return nil
        }

        return [
          "value": self.sleepValueString(for: categorySample.value),
          "startDate": categorySample.startDate,
          "endDate": categorySample.endDate
        ]
      }

      completion(data)
    }

    healthStore.execute(query)
  }

  private func evaluateJavascript(data: [Int], type: String, frequency: String, activityTime: String) -> String {
    let samples = sampleAxis(for: frequency, count: data.count)
    let jsonArrayData = jsonString(from: data)
    return "DetailedGraph.updateData(\(samples),\(jsonArrayData),'\(type)','\(frequency)','\(activityTime)')"
  }

  private func preprocessEmbellishRequest(
    steps: [Int],
    calories: [Int],
    distance: [Int],
    date: Date
  ) -> [[String: Any]] {
    let embellishData = steps.enumerated().map { index, step -> [String: Any] in
      [
        "st": step,
        "c": index < calories.count ? calories[index] : 0,
        "d": index < distance.count ? distance[index] : 0,
        "h": index,
        "s": ""
      ]
    }

    return [[
      "data": embellishData,
      "dt": millisecondsSince1970(date)
    ]]
  }

  private func callSyncData(days: Int, dates: [Date], result: @escaping FlutterResult) {
    let group = DispatchGroup()
    var steps: [Int] = []
    var calories: [Int] = []
    var distanceData: [Int] = []
    var activityMap: [Int64: Double] = [:]
    var sleepMap: [Int64: (sleepTime: Int64, wakeupTime: Int64)] = [:]

    group.enter()
    fetchStepCount(for: Date(), frequency: "custom", days: days) { stepData, calorieData in
      steps = stepData
      calories = calorieData
      group.leave()
    }

    group.enter()
    fetchDistanceWalkingRunning(for: Date(), frequency: "custom", days: days) { data in
      distanceData = data
      group.leave()
    }

    group.enter()
    fetchActivityDurations(for: Date(), frequency: "custom", days: days) { _, data in
      for item in data {
        guard let date = item["date"] as? Date, let value = item["value"] as? Double else {
          continue
        }

        activityMap[self.millisecondsSince1970(self.calendar.startOfDay(for: date))] = value
      }
      group.leave()
    }

    group.enter()
    fetchSleepSamples(for: Date(), frequency: "custom", days: days) { samples in
      sleepMap = self.groupedSleepWindowByDay(samples)
      group.leave()
    }

    group.notify(queue: .main) {
      let fitnessData = dates.enumerated().map { index, date -> [String: Any] in
        let dayKey = self.millisecondsSince1970(self.calendar.startOfDay(for: date))
        var item: [String: Any] = [
          "steps": index < steps.count ? steps[index] : 0,
          "calories": index < calories.count ? calories[index] : 0,
          "distance": index < distanceData.count ? distanceData[index] : 0,
          "date": dayKey
        ]

        if let activity = activityMap[dayKey] {
          item["activity"] = activity
        }

        if let sleep = sleepMap[dayKey] {
          item["sleep"] = "\(sleep.sleepTime)-\(sleep.wakeupTime)"
        }

        return item
      }

      result([["fitnessData": fitnessData]])
    }
  }

  private func getDateRanges(from startDate: Date) -> [Date] {
    let startOfToday = calendar.startOfDay(for: Date())
    let endOfToday = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? Date()
    var numberOfDays = calendar.dateComponents([.day], from: startDate, to: endOfToday).day ?? 0

    if numberOfDays <= 0 {
      return []
    }

    if numberOfDays > 30 {
      numberOfDays = 30
    }

    let normalizedStart = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: endOfToday) ?? startDate
    return (0..<numberOfDays).compactMap { offset in
      calendar.date(byAdding: .day, value: offset, to: normalizedStart)
    }
  }

  private func currentBmrCaloriesPerHour() -> Int {
    do {
      switch try healthStore.biologicalSex().biologicalSex {
      case .male:
        return 1662 / 24
      case .female:
        return 1493 / 24
      default:
        return 1493 / 24
      }
    } catch {
      return 1493 / 24
    }
  }

  private func sleepValueString(for value: Int) -> String {
    if value == HKCategoryValueSleepAnalysis.inBed.rawValue {
      return "INBED"
    }

    if value == HKCategoryValueSleepAnalysis.asleep.rawValue {
      return "ASLEEP"
    }

    if #available(iOS 16.0, *) {
      let asleepValues = [
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
      ]

      if asleepValues.contains(value) {
        return "ASLEEP"
      }
    }

    return "UNKNOWN"
  }

  private func groupedSleepWindowByDay(_ samples: [[String: Any]]) -> [Int64: (sleepTime: Int64, wakeupTime: Int64)] {
    var sleepMap: [Int64: (sleepTime: Int64, wakeupTime: Int64)] = [:]

    for sample in samples {
      guard let value = sample["value"] as? String,
        value == "INBED" || value == "ASLEEP",
        let startDate = sample["startDate"] as? Date,
        let endDate = sample["endDate"] as? Date
      else {
        continue
      }

      let dayKey = millisecondsSince1970(calendar.startOfDay(for: endDate))
      let sleepTime = millisecondsSince1970(startDate)
      let wakeupTime = millisecondsSince1970(endDate)

      if let existing = sleepMap[dayKey] {
        sleepMap[dayKey] = (
          sleepTime: min(existing.sleepTime, sleepTime),
          wakeupTime: max(existing.wakeupTime, wakeupTime)
        )
      } else {
        sleepMap[dayKey] = (sleepTime: sleepTime, wakeupTime: wakeupTime)
      }
    }

    return sleepMap
  }

  private func groupSleepSamplesByDay(_ samples: [[String: Any]]) -> [[String: Any]] {
    var groupedByDay: [Int64: [String: Any]] = [:]

    for sample in samples {
      guard let value = sample["value"] as? String,
        value == "INBED" || value == "ASLEEP",
        let startDate = sample["startDate"] as? Date,
        let endDate = sample["endDate"] as? Date
      else {
        continue
      }

      let dayStart = calendar.startOfDay(for: endDate)
      let dayKey = millisecondsSince1970(dayStart)
      let sleepTime = millisecondsSince1970(startDate)
      let wakeupTime = millisecondsSince1970(endDate)
      let dayLabel = shortWeekdaySymbol(for: endDate)

      if var existing = groupedByDay[dayKey] {
        existing["sleepTime"] = min((existing["sleepTime"] as? Int64) ?? sleepTime, sleepTime)
        existing["wakeupTime"] = max((existing["wakeupTime"] as? Int64) ?? wakeupTime, wakeupTime)
        groupedByDay[dayKey] = existing
      } else {
        groupedByDay[dayKey] = [
          "sleepTime": sleepTime,
          "wakeupTime": wakeupTime,
          "day": dayLabel,
          "startTimestamp": dayKey
        ]
      }
    }

    return groupedByDay.keys.sorted().compactMap { groupedByDay[$0] }
  }

  private func padSleepDataIfNeeded(_ data: [[String: Any]]) -> [[String: Any]] {
    guard !data.isEmpty, data.count < 7, let lastItem = data.last else {
      return data
    }

    var paddedData = data
    var currentDate = Date(timeIntervalSince1970: Double((lastItem["startTimestamp"] as? Int64) ?? 0) / 1000)

    while paddedData.count < 7 {
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
      paddedData.append([
        "sleepTime": 0,
        "wakeupTime": 0,
        "day": shortWeekdaySymbol(for: currentDate),
        "startTimestamp": millisecondsSince1970(currentDate)
      ])
    }

    return paddedData
  }

  private func sampleAxis(for frequency: String, count: Int) -> String {
    switch frequency {
    case "day":
      return jsonString(from: Array(1...24))
    case "week":
      return jsonString(from: Array(1...7))
    case "month":
      return jsonString(from: Array(1...31))
    default:
      let upperBound = max(count, 0)
      return jsonString(from: upperBound == 0 ? [] : Array(1...upperBound))
    }
  }

  private func jsonString(from object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object, options: [])
    else {
      return "[]"
    }

    return String(data: data, encoding: .utf8) ?? "[]"
  }

  private func dateRange(for endDate: Date, frequency: String, days: Int) -> (start: Date, end: Date)? {
    switch frequency {
    case "day":
      let startDate = calendar.startOfDay(for: endDate)
      let endDatePeriod = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDate) ?? endDate
      return (startDate, endDatePeriod)
    case "week":
      guard let range = calendar.dateInterval(of: .weekOfYear, for: endDate) else {
        return nil
      }
      return (range.start, range.end.addingTimeInterval(-1))
    case "month":
      guard let range = calendar.dateInterval(of: .month, for: endDate) else {
        return nil
      }
      return (range.start, range.end.addingTimeInterval(-1))
    case "custom":
      let normalizedDays = max(days, 1)
      let startDate = calendar.date(byAdding: .day, value: 1 - normalizedDays, to: endDate) ?? endDate
      return (calendar.startOfDay(for: startDate), endDate)
    default:
      return nil
    }
  }

  private func sleepDateRange(for endDate: Date, frequency: String, days: Int) -> (start: Date, end: Date)? {
    guard var range = dateRange(for: endDate, frequency: frequency, days: days) else {
      return nil
    }

    if frequency == "day" {
      range.start = range.start.addingTimeInterval(-2 * 60 * 60)
    }

    return range
  }

  private func activityPredicate(startDate: Date, endDate: Date) -> NSPredicate {
    let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let userEnteredPredicate = HKQuery.predicateForObjects(
      withMetadataKey: HKMetadataKeyWasUserEntered,
      operatorType: .notEqualTo,
      value: NSNumber(value: true)
    )

    return NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, userEnteredPredicate])
  }

  private func shortWeekdaySymbol(for date: Date) -> String {
    let weekday = calendar.component(.weekday, from: date) - 1
    return calendar.shortWeekdaySymbols[weekday]
  }

  private var hasHealthAuthorization: Bool {
    guard let stepCountType = stepCountType else {
      return false
    }

    return healthStore.authorizationStatus(for: stepCountType) == .sharingAuthorized
  }

  private var writeTypes: Set<HKSampleType> {
    guard let stepCountType = stepCountType else {
      return []
    }

    return [stepCountType]
  }

  private var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = []

    if let stepCountType {
      types.insert(stepCountType)
    }

    if let sleepAnalysisType {
      types.insert(sleepAnalysisType)
    }

    if let biologicalSexType {
      types.insert(biologicalSexType)
    }

    if let distanceWalkingRunningType {
      types.insert(distanceWalkingRunningType)
    }

    return types
  }

  private var stepCountType: HKQuantityType? {
    HKObjectType.quantityType(forIdentifier: .stepCount)
  }

  private var sleepAnalysisType: HKCategoryType? {
    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
  }

  private var biologicalSexType: HKCharacteristicType? {
    HKObjectType.characteristicType(forIdentifier: .biologicalSex)
  }

  private var distanceWalkingRunningType: HKQuantityType? {
    HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
  }

  private func millisecondsSince1970(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
  }

  private func int64Value(for value: Any?) -> Int64 {
    if let number = value as? NSNumber {
      return number.int64Value
    }

    if let string = value as? String, let int64 = Int64(string) {
      return int64
    }

    return 0
  }

  private func timestampValue(from arguments: Any?) -> Double {
    if let number = arguments as? NSNumber {
      return number.doubleValue
    }

    if let dictionary = arguments as? [String: Any] {
      if let googleFitLastSync = dictionary["googleFitLastSync"] {
        return Double(int64Value(for: googleFitLastSync))
      }

      if let hourlyLastSync = dictionary["gfHourlyLastSync"] {
        return Double(int64Value(for: hourlyLastSync))
      }

      if let timestamp = dictionary["timestamp"] {
        return Double(int64Value(for: timestamp))
      }
    }

    return 0
  }
}
