//
//  MemoryMonitor.swift
//  Ollvy
//
//  Created on October 29, 2025.
//

import Foundation
import UIKit

/// Monitors memory usage and responds to memory warnings to prevent crashes
@MainActor
class MemoryMonitor {
    /// Shared singleton instance
    static let shared = MemoryMonitor()

    /// Memory warning notification name
    static let memoryWarningNotification = Notification.Name("OllvyMemoryWarning")

    private var memoryWarningObserver: NSObjectProtocol?

    private init() {}

    /// Start monitoring for memory warnings
    func startMonitoring() {
        // FIXED: Use DispatchQueue.main.async instead of Task { @MainActor } to ensure
        // state updates are deferred to next run loop, avoiding "Publishing changes" warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleMemoryWarning()
            }
        }

        AppLogger.app.info("Memory monitoring started")
    }

    /// Stop monitoring for memory warnings
    func stopMonitoring() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
            AppLogger.app.info("Memory monitoring stopped")
        }
    }

    /// Handle memory warning by reducing resource usage
    private func handleMemoryWarning() {
        AppLogger.app.warning("MEMORY WARNING RECEIVED - Taking action to reduce memory footprint")

        // 1. Reduce texture quality for future captures
        let wasHighRes = UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
        if wasHighRes {
            UserDefaults.standard.set(false, forKey: AppDefaultsKey.enableHighResCapture)
            AppLogger.app.info("Disabled high-resolution texture capture (4K → 2K)")
        }

        // 2. Clear URL cache
        let cachedSize = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
        URLCache.shared.removeAllCachedResponses()
        AppLogger.app.info("Cleared URL cache (\(cachedSize / 1024 / 1024) MB freed)")

        // 3. Clear image cache if available
        // (Add specific cache clearing for any image caching frameworks you use)

        // 4. Request garbage collection
        // Note: Swift doesn't have explicit GC, but we can nil out references
        AppLogger.app.debug("Requesting memory compaction")

        // 5. Post notification to all ViewModels to clear their caches
        NotificationCenter.default.post(
            name: MemoryMonitor.memoryWarningNotification,
            object: nil
        )
        AppLogger.app.info("Notified all view models to clear caches")

        // 6. Log current memory usage (for debugging)
        logMemoryUsage()
    }

    /// Log current memory usage (for debugging)
    private func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            AppLogger.app.info("Current memory usage: \(String(format: "%.2f", usedMB)) MB")
        }
    }

    deinit {
        // Remove observer directly without calling stopMonitoring() to avoid actor isolation issue
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
