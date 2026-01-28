//
//  VersionedMetricsWrapper.swift
//  Ollvy
//
//  Versioned JSON wrapper for metrics with migration support
//  Handles schema evolution and backward compatibility
//

import Foundation
import UIKit

/// Semantic version for metrics data format
public struct MetricsVersion: Codable, Equatable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Current version of the metrics format
    public static let current = MetricsVersion(major: 1, minor: 1, patch: 0)

    /// Legacy version (before versioning was added)
    public static let legacy = MetricsVersion(major: 1, minor: 0, patch: 0)

    /// Version string (e.g., "1.1.0")
    public var versionString: String {
        return "\(major).\(minor).\(patch)"
    }

    /// Check if this version is compatible with another version
    /// - Parameter other: Version to check compatibility with
    /// - Returns: True if compatible (major version matches)
    public func isCompatible(with other: MetricsVersion) -> Bool {
        return self.major == other.major
    }

    /// Check if migration is required from another version
    /// - Parameter from: Source version
    /// - Returns: True if migration is needed
    public func requiresMigration(from: MetricsVersion) -> Bool {
        return self != from
    }

    // Comparable conformance
    public static func < (lhs: MetricsVersion, rhs: MetricsVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Result of loading versioned Face3D metrics
public enum Face3DMetricsLoadResult {
    case success(Face3DMetrics, version: MetricsVersion)
    case migrated(Face3DMetrics, from: MetricsVersion, to: MetricsVersion)
    case incompatible(version: MetricsVersion, reason: String)
    case corrupted(error: Error)
    case notFound

    /// Get metrics if available
    public var metrics: Face3DMetrics? {
        switch self {
        case .success(let metrics, _), .migrated(let metrics, _, _):
            return metrics
        case .incompatible, .corrupted, .notFound:
            return nil
        }
    }

    /// Get version if available
    public var version: MetricsVersion? {
        switch self {
        case .success(_, let version), .migrated(_, _, let version):
            return version
        case .incompatible(let version, _):
            return version
        case .corrupted, .notFound:
            return nil
        }
    }

    /// Check if metrics are usable
    public var isSuccess: Bool {
        switch self {
        case .success, .migrated:
            return true
        case .incompatible, .corrupted, .notFound:
            return false
        }
    }

    /// User-friendly description
    public var userMessage: String {
        switch self {
        case .success:
            return "Previous scan loaded"
        case .migrated:
            return "Previous scan updated to work with this version"
        case .incompatible:
            return "This scan is from an older version and can't be opened"
        case .corrupted:
            return "This scan data appears to be damaged"
        case .notFound:
            return "No previous scan found"
        }
    }
}

/// Result of loading versioned Emotional metrics
public enum EmotionalMetricsLoadResult {
    case success(EmotionalMetrics, version: MetricsVersion)
    case migrated(EmotionalMetrics, from: MetricsVersion, to: MetricsVersion)
    case incompatible(version: MetricsVersion, reason: String)
    case corrupted(error: Error)
    case notFound

    /// Get metrics if available
    public var metrics: EmotionalMetrics? {
        switch self {
        case .success(let metrics, _), .migrated(let metrics, _, _):
            return metrics
        case .incompatible, .corrupted, .notFound:
            return nil
        }
    }

    /// Get version if available
    public var version: MetricsVersion? {
        switch self {
        case .success(_, let version), .migrated(_, _, let version):
            return version
        case .incompatible(let version, _):
            return version
        case .corrupted, .notFound:
            return nil
        }
    }

    /// Check if metrics are usable
    public var isSuccess: Bool {
        switch self {
        case .success, .migrated:
            return true
        case .incompatible, .corrupted, .notFound:
            return false
        }
    }

    /// User-friendly description
    public var userMessage: String {
        switch self {
        case .success:
            return "Previous scan loaded"
        case .migrated:
            return "Previous scan updated to work with this version"
        case .incompatible:
            return "This scan is from an older version and can't be opened"
        case .corrupted:
            return "This scan data appears to be damaged"
        case .notFound:
            return "No previous scan found"
        }
    }
}

/// Versioned wrapper for Face3DMetrics
public struct VersionedFace3DMetrics: Codable {
    /// Schema version
    public let version: MetricsVersion

    /// Serialized metrics data (base64 encoded JSON)
    public let metricsData: String

    /// Timestamp when this was saved
    public let savedAt: Date

    /// Device information
    public let deviceInfo: DeviceSaveInfo?

    public init(metrics: Face3DMetrics, version: MetricsVersion = .current) throws {
        self.version = version
        self.savedAt = Date()
        self.deviceInfo = DeviceSaveInfo.current

        // Encode metrics to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metrics)
        self.metricsData = data.base64EncodedString()
    }

    /// Decode metrics from this wrapper
    public func decodeMetrics() throws -> Face3DMetrics {
        guard let data = Data(base64Encoded: metricsData) else {
            throw MetricsDecodingError.invalidBase64
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Face3DMetrics.self, from: data)
    }
}

/// Versioned wrapper for EmotionalMetrics
public struct VersionedEmotionalMetrics: Codable {
    /// Schema version
    public let version: MetricsVersion

    /// Serialized metrics data (base64 encoded JSON)
    public let metricsData: String

    /// Timestamp when this was saved
    public let savedAt: Date

    /// Device information
    public let deviceInfo: DeviceSaveInfo?

    public init(metrics: EmotionalMetrics, version: MetricsVersion = .current) throws {
        self.version = version
        self.savedAt = Date()
        self.deviceInfo = DeviceSaveInfo.current

        // Encode metrics to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metrics)
        self.metricsData = data.base64EncodedString()
    }

    /// Decode metrics from this wrapper
    public func decodeMetrics() throws -> EmotionalMetrics {
        guard let data = Data(base64Encoded: metricsData) else {
            throw MetricsDecodingError.invalidBase64
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(EmotionalMetrics.self, from: data)
    }
}

/// Device information stored with metrics
public struct DeviceSaveInfo: Codable {
    public let model: String
    public let osVersion: String
    public let appVersion: String?

    public static var current: DeviceSaveInfo {
        return DeviceSaveInfo(
            model: UIDevice.current.model,
            osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }
}

/// Decoding errors
public enum MetricsDecodingError: LocalizedError {
    case invalidBase64
    case incompatibleVersion(found: MetricsVersion, required: MetricsVersion)
    case migrationFailed(from: MetricsVersion, to: MetricsVersion, reason: String)
    case corruptedData

    public var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Metrics data is not valid base64"
        case .incompatibleVersion(let found, let required):
            return "Incompatible version: found v\(found.versionString), required v\(required.versionString)"
        case .migrationFailed(let from, let to, let reason):
            return "Migration failed from v\(from.versionString) to v\(to.versionString): \(reason)"
        case .corruptedData:
            return "Metrics data is corrupted"
        }
    }
}

/// Metrics migration manager
public class MetricsMigrationManager {

    /// Migrate Face3DMetrics from old version to current
    /// - Parameters:
    ///   - data: Raw JSON data
    ///   - fromVersion: Source version
    /// - Returns: Migrated metrics
    public static func migrateFace3DMetrics(
        from data: Data,
        fromVersion: MetricsVersion
    ) throws -> Face3DMetrics {
        // If current version, no migration needed
        if fromVersion == .current {
            let decoder = JSONDecoder()
            return try decoder.decode(Face3DMetrics.self, from: data)
        }

        // Migration path: v1.0.0 -> v1.1.0
        if fromVersion == .legacy && MetricsVersion.current.major == 1 && MetricsVersion.current.minor >= 1 {
            return try migrateLegacyToV1_1(data: data)
        }

        // No migration path available
        throw MetricsDecodingError.incompatibleVersion(found: fromVersion, required: .current)
    }

    /// Migrate from legacy (v1.0.0) to v1.1.0
    /// In v1.0.0, some optional fields might not exist
    private static func migrateLegacyToV1_1(data: Data) throws -> Face3DMetrics {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode with lenient settings
        // If any optional fields are missing, they'll be nil which is fine
        do {
            return try decoder.decode(Face3DMetrics.self, from: data)
        } catch {
            // If decoding fails, throw migration error
            throw MetricsDecodingError.migrationFailed(
                from: .legacy,
                to: .current,
                reason: "Failed to decode legacy data: \(error.localizedDescription)"
            )
        }
    }

    /// Migrate EmotionalMetrics from old version to current
    /// - Parameters:
    ///   - data: Raw JSON data
    ///   - fromVersion: Source version
    /// - Returns: Migrated metrics
    public static func migrateEmotionalMetrics(
        from data: Data,
        fromVersion: MetricsVersion
    ) throws -> EmotionalMetrics {
        // If current version, no migration needed
        if fromVersion == .current {
            let decoder = JSONDecoder()
            return try decoder.decode(EmotionalMetrics.self, from: data)
        }

        // Migration path: v1.0.0 -> v1.1.0
        if fromVersion == .legacy && MetricsVersion.current.major == 1 && MetricsVersion.current.minor >= 1 {
            return try migrateLegacyEmotionalToV1_1(data: data)
        }

        // No migration path available
        throw MetricsDecodingError.incompatibleVersion(found: fromVersion, required: .current)
    }

    /// Migrate emotional metrics from legacy to v1.1.0
    private static func migrateLegacyEmotionalToV1_1(data: Data) throws -> EmotionalMetrics {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(EmotionalMetrics.self, from: data)
        } catch {
            throw MetricsDecodingError.migrationFailed(
                from: .legacy,
                to: .current,
                reason: "Failed to decode legacy emotional data: \(error.localizedDescription)"
            )
        }
    }
}

/// Versioned metrics loader with migration support
public class VersionedMetricsLoader {

    /// Load Face3DMetrics with version checking and migration
    /// - Parameter data: Versioned wrapper data or legacy raw data
    /// - Returns: Load result with metrics or error
    public static func loadFace3DMetrics(from data: Data) -> Face3DMetricsLoadResult {
        // Try to decode as versioned wrapper first
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let wrapper = try? decoder.decode(VersionedFace3DMetrics.self, from: data) {
            // Versioned data
            return loadVersionedFace3DMetrics(wrapper: wrapper)
        }

        // Try legacy format (direct Face3DMetrics without wrapper)
        return loadLegacyFace3DMetrics(data: data)
    }

    /// Load versioned Face3DMetrics
    private static func loadVersionedFace3DMetrics(wrapper: VersionedFace3DMetrics) -> Face3DMetricsLoadResult {
        do {
            // Check version compatibility
            guard wrapper.version.isCompatible(with: .current) else {
                return .incompatible(
                    version: wrapper.version,
                    reason: "Major version mismatch (found v\(wrapper.version.versionString), need v\(MetricsVersion.current.major).x.x)"
                )
            }

            // Decode metrics
            let metrics = try wrapper.decodeMetrics()

            // Check if migration was needed
            if wrapper.version != .current {
                return .migrated(metrics, from: wrapper.version, to: .current)
            } else {
                return .success(metrics, version: wrapper.version)
            }
        } catch {
            return .corrupted(error: error)
        }
    }

    /// Load legacy (unwrapped) Face3DMetrics
    private static func loadLegacyFace3DMetrics(data: Data) -> Face3DMetricsLoadResult {
        do {
            // Try to migrate from legacy format
            let metrics = try MetricsMigrationManager.migrateFace3DMetrics(
                from: data,
                fromVersion: .legacy
            )
            return .migrated(metrics, from: .legacy, to: .current)
        } catch {
            return .corrupted(error: error)
        }
    }

    /// Load EmotionalMetrics with version checking and migration
    /// - Parameter data: Versioned wrapper data or legacy raw data
    /// - Returns: Load result with metrics or error
    public static func loadEmotionalMetrics(from data: Data) -> EmotionalMetricsLoadResult {
        // Try to decode as versioned wrapper first
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let wrapper = try? decoder.decode(VersionedEmotionalMetrics.self, from: data) {
            return loadVersionedEmotionalMetrics(wrapper: wrapper)
        }

        // Try legacy format
        return loadLegacyEmotionalMetrics(data: data)
    }

    /// Load versioned EmotionalMetrics
    private static func loadVersionedEmotionalMetrics(wrapper: VersionedEmotionalMetrics) -> EmotionalMetricsLoadResult {
        do {
            guard wrapper.version.isCompatible(with: .current) else {
                return .incompatible(
                    version: wrapper.version,
                    reason: "Major version mismatch"
                )
            }

            let metrics = try wrapper.decodeMetrics()

            if wrapper.version != .current {
                return .migrated(metrics, from: wrapper.version, to: .current)
            } else {
                return .success(metrics, version: wrapper.version)
            }
        } catch {
            return .corrupted(error: error)
        }
    }

    /// Load legacy EmotionalMetrics
    private static func loadLegacyEmotionalMetrics(data: Data) -> EmotionalMetricsLoadResult {
        do {
            let metrics = try MetricsMigrationManager.migrateEmotionalMetrics(
                from: data,
                fromVersion: .legacy
            )
            return .migrated(metrics, from: .legacy, to: .current)
        } catch {
            return .corrupted(error: error)
        }
    }
}
