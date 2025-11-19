import Foundation
import HealthKit

/// iOS HealthKit Plugin for Godot 4
/// Compatible with iOS 15+ (tested on iOS 18)
/// Provides step count and distance tracking for LenKinVerse
@objc public class HealthKitPlugin: NSObject {

    private let healthStore = HKHealthStore()
    private var isAuthorized = false

    // MARK: - Godot Plugin Registration

    @objc public static func register() {
        Engine.get_singleton().add_singleton(
            singleton_name: "HealthKit",
            singleton: HealthKitPlugin()
        )
    }

    // MARK: - Authorization

    /// Request authorization for step count and distance
    /// Returns: Dictionary with "granted" bool and "error" string
    @objc public func request_authorization(_ types: [String]) -> Dictionary<String, Any> {
        guard HKHealthStore.isHealthDataAvailable() else {
            return [
                "granted": false,
                "error": "Health data not available on this device"
            ]
        }

        // Define data types to read
        var readTypes = Set<HKObjectType>()

        for typeString in types {
            switch typeString {
            case "step_count":
                if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                    readTypes.insert(stepType)
                }
            case "distance_walking_running":
                if let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
                    readTypes.insert(distanceType)
                }
            default:
                break
            }
        }

        // Request authorization (async in iOS 15+)
        var result: [String: Any] = ["granted": false]
        let semaphore = DispatchSemaphore(value: 0)

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            self.isAuthorized = success
            result["granted"] = success
            if let error = error {
                result["error"] = error.localizedDescription
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    // MARK: - Data Queries

    /// Get step count between dates
    /// Parameters: Dictionary with "start_date" and "end_date" (Godot datetime dicts)
    /// Returns: Dictionary with "steps" int and "success" bool
    @objc public func get_steps(_ params: Dictionary<String, Any>) -> Dictionary<String, Any> {
        guard isAuthorized else {
            return ["success": false, "error": "Not authorized", "steps": 0]
        }

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return ["success": false, "error": "Step type unavailable", "steps": 0]
        }

        guard let startDate = parseDate(params["start_date"]),
              let endDate = parseDate(params["end_date"]) else {
            return ["success": false, "error": "Invalid date format", "steps": 0]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        var result: [String: Any] = ["success": false, "steps": 0]
        let semaphore = DispatchSemaphore(value: 0)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            if let error = error {
                result["error"] = error.localizedDescription
            } else if let sum = statistics?.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                result["success"] = true
                result["steps"] = steps
            }
            semaphore.signal()
        }

        healthStore.execute(query)
        semaphore.wait()

        return result
    }

    /// Get distance walked/run between dates
    /// Parameters: Dictionary with "start_date" and "end_date"
    /// Returns: Dictionary with "distance" float (meters) and "success" bool
    @objc public func get_distance(_ params: Dictionary<String, Any>) -> Dictionary<String, Any> {
        guard isAuthorized else {
            return ["success": false, "error": "Not authorized", "distance": 0.0]
        }

        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return ["success": false, "error": "Distance type unavailable", "distance": 0.0]
        }

        guard let startDate = parseDate(params["start_date"]),
              let endDate = parseDate(params["end_date"]) else {
            return ["success": false, "error": "Invalid date format", "distance": 0.0]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        var result: [String: Any] = ["success": false, "distance": 0.0]
        let semaphore = DispatchSemaphore(value: 0)

        let query = HKStatisticsQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            if let error = error {
                result["error"] = error.localizedDescription
            } else if let sum = statistics?.sumQuantity() {
                let distance = sum.doubleValue(for: HKUnit.meter())
                result["success"] = true
                result["distance"] = distance
            }
            semaphore.signal()
        }

        healthStore.execute(query)
        semaphore.wait()

        return result
    }

    // MARK: - Helper Methods

    /// Parse Godot datetime dictionary to Date
    private func parseDate(_ dateDict: Any?) -> Date? {
        guard let dict = dateDict as? Dictionary<String, Int> else {
            return nil
        }

        var components = DateComponents()
        components.year = dict["year"]
        components.month = dict["month"]
        components.day = dict["day"]
        components.hour = dict["hour"] ?? 0
        components.minute = dict["minute"] ?? 0
        components.second = dict["second"] ?? 0

        return Calendar.current.date(from: components)
    }
}
