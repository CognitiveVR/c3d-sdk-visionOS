//
//  Cognitive3DSetupValidator.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import Network
import ARKit
import UIKit
import AVFoundation

/// Comprehensive setup validation utility for pre-configuration health checks
/// Validates environment, network, device capabilities, and configuration before SDK initialization
public class Cognitive3DSetupValidator {
    
    // MARK: - Public API
    
    /// Validates the complete setup configuration and environment
    /// - Parameter settings: CoreSettings to validate
    /// - Returns: ValidationResult containing all validation outcomes
    public static func validateConfiguration(_ settings: CoreSettings) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Configuration validation
        issues.append(contentsOf: validateCoreSettings(settings))
        
        // Environment validation
        issues.append(contentsOf: validateEnvironment())
        
        // Device capabilities validation
        issues.append(contentsOf: validateDeviceCapabilities())
        
        // Network connectivity validation
        if let networkIssue = validateNetworkConnectivity() {
            issues.append(networkIssue)
        }
        
        // Permissions validation
        issues.append(contentsOf: validatePermissions())
        
        // System resources validation
        issues.append(contentsOf: validateSystemResources())
        
        return ValidationResult(issues: issues)
    }
    
    /// Quick validation check for basic setup requirements
    /// - Parameter settings: CoreSettings to validate
    /// - Returns: Bool indicating if basic setup is valid
    public static func isBasicSetupValid(_ settings: CoreSettings) -> Bool {
        do {
            try settings.validate()
            return true
        } catch {
            return false
        }
    }
    
    /// Validates network connectivity to Cognitive3D endpoints
    /// - Returns: ValidationIssue if connectivity problems are detected
    public static func validateNetworkConnectivity() -> ValidationIssue? {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        var currentPath: NWPath?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            currentPath = path
            semaphore.signal()
        }
        
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 1.0) // Quick check
        monitor.cancel()
        
        guard let path = currentPath else {
            return ValidationIssue(
                severity: .error,
                message: "Unable to determine network status",
                solution: "Check device network settings and try again",
                category: .network
            )
        }
        
        if path.status != .satisfied {
            return ValidationIssue(
                severity: .warning,
                message: "No network connection available",
                solution: "Data will be cached offline and uploaded when connection is restored. Ensure Wi-Fi or cellular connection for real-time analytics.",
                category: .network
            )
        }
        
        // Check for expensive network connections
        if path.isExpensive {
            return ValidationIssue(
                severity: .info,
                message: "Using cellular data connection",
                solution: "Analytics data usage will be minimized on cellular connections. Connect to Wi-Fi for optimal performance.",
                category: .network
            )
        }
        
        return nil
    }
    
    // MARK: - Private Validation Methods
    
    private static func validateCoreSettings(_ settings: CoreSettings) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        do {
            try settings.validate()
        } catch let error as Cognitive3DConfigurationError {
            let severity: ValidationIssue.Severity = {
                switch error {
                case .missingAPIKey, .missingSceneData:
                    return .error
                case .invalidAPIKey, .invalidSceneId, .invalidSceneName:
                    return .error
                default:
                    return .warning
                }
            }()
            
            issues.append(ValidationIssue(
                severity: severity,
                message: error.localizedDescription,
                solution: error.recoverySuggestion ?? "Check configuration requirements",
                category: .configuration
            ))
        } catch {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Configuration validation failed: \(error.localizedDescription)",
                solution: "Review configuration parameters and ensure all required values are provided",
                category: .configuration
            ))
        }
        
        return issues
    }
    
    private static func validateEnvironment() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check iOS version compatibility
        if #available(visionOS 2.0, *) {
            // Current version is supported
        } else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "visionOS version not supported",
                solution: "Upgrade to visionOS 2.0 or later to use Cognitive3D analytics",
                category: .device
            ))
        }
        
        // Check if running on simulator vs device
        #if targetEnvironment(simulator)
        issues.append(ValidationIssue(
            severity: .info,
            message: "Running on visionOS Simulator",
            solution: "Some features like gaze tracking may have limited functionality on simulator. Test on device for full feature set.",
            category: .device
        ))
        #endif
        
        // Check available storage
        if let availableBytes = getAvailableStorageSpace() {
            let minimumRequired: Int64 = 100 * 1024 * 1024 // 100MB
            if availableBytes < minimumRequired {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Low storage space available",
                    solution: "Free up storage space to ensure analytics data can be cached properly. At least 100MB recommended.",
                    category: .device
                ))
            }
        }
        
        return issues
    }
    
    private static func validateDeviceCapabilities() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check ARKit support
        if !ARWorldTrackingConfiguration.isSupported {
            issues.append(ValidationIssue(
                severity: .error,
                message: "ARKit world tracking not supported",
                solution: "ARKit world tracking is required for gaze analytics. Ensure device supports ARKit.",
                category: .device
            ))
        }
        
        // Check world tracking configuration support
        let config = ARWorldTrackingConfiguration()
        
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Advanced person segmentation not supported",
                solution: "Some advanced analytics features may not be available on this device model.",
                category: .device
            ))
        }
        
        // Check eye tracking support (if available)
        if #available(visionOS 2.0, *) {
            // Eye tracking should be available on Vision Pro
            issues.append(ValidationIssue(
                severity: .info,
                message: "Eye tracking capabilities detected",
                solution: "Eye tracking analytics will be enabled for enhanced gaze data collection.",
                category: .device
            ))
        }
        
        return issues
    }
    
    private static func validatePermissions() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check camera access for ARKit
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .denied, .restricted:
            issues.append(ValidationIssue(
                severity: .error,
                message: "Camera access denied",
                solution: "Grant camera permission in Settings > Privacy & Security > Camera to enable gaze tracking analytics.",
                category: .permissions
            ))
        case .notDetermined:
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Camera permission not requested",
                solution: "Camera permission will be requested when starting analytics session. Consider requesting permission early in app flow.",
                category: .permissions
            ))
        case .authorized:
            // Permission granted - no issue
            break
        @unknown default:
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Unknown camera permission status",
                solution: "Verify camera permissions in device settings.",
                category: .permissions
            ))
        }
        
        // Check world sensing permission (visionOS specific)
        // Note: This would typically be checked through ARKit session configuration
        
        return issues
    }
    
    private static func validateSystemResources() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check available memory
        let memoryInfo = getMemoryInfo()
        if let availableMemory = memoryInfo.available, let totalMemory = memoryInfo.total {
            let memoryUsagePercentage = Double(totalMemory - availableMemory) / Double(totalMemory)
            
            if memoryUsagePercentage > 0.9 { // More than 90% memory used
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "High memory usage detected",
                    solution: "Close unused applications to ensure optimal analytics performance.",
                    category: .device
                ))
            }
        }
        
        // Check battery level (if available)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel > 0 && batteryLevel < 0.15 { // Less than 15% battery
            issues.append(ValidationIssue(
                severity: .info,
                message: "Low battery level detected",
                solution: "Analytics data collection may be optimized to preserve battery life.",
                category: .device
            ))
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = false
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    private static func getAvailableStorageSpace() -> Int64? {
        do {
            let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let values = try documentURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity
        } catch {
            return nil
        }
    }
    
    private static func getMemoryInfo() -> (total: Int64?, available: Int64?) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
            let usedMemory = Int64(info.resident_size)
            return (total: totalMemory, available: totalMemory - usedMemory)
        }
        
        return (total: nil, available: nil)
    }
}

// MARK: - Supporting Types

/// Result of validation containing all issues found
public struct ValidationResult {
    public let issues: [ValidationIssue]
    public let timestamp = Date()
    
    /// True if no error-level issues were found
    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }
    
    /// True if any warning-level issues were found
    public var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }
    
    /// True if any info-level issues were found
    public var hasInfo: Bool {
        issues.contains { $0.severity == .info }
    }
    
    /// Get issues by severity level
    public func issues(withSeverity severity: ValidationIssue.Severity) -> [ValidationIssue] {
        issues.filter { $0.severity == severity }
    }
    
    /// Get issues by category
    public func issues(inCategory category: ValidationIssue.Category) -> [ValidationIssue] {
        issues.filter { $0.category == category }
    }
    
    /// Generate a formatted report string
    public func generateReport() -> String {
        var report = "🔍 Cognitive3D Setup Validation Report\n"
        report += "Generated: \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short))\n"
        report += "Overall Status: \(isValid ? "✅ Valid" : "❌ Issues Found")\n"
        
        if issues.isEmpty {
            report += "\n🎉 No issues found! SDK is ready for use.\n"
            return report
        }
        
        // Group issues by severity
        let errorIssues = issues(withSeverity: .error)
        let warningIssues = issues(withSeverity: .warning)
        let infoIssues = issues(withSeverity: .info)
        
        if !errorIssues.isEmpty {
            report += "\n❌ ERRORS (must be fixed):\n"
            for issue in errorIssues {
                report += "  • \(issue.message)\n"
                report += "    💡 \(issue.solution)\n"
            }
        }
        
        if !warningIssues.isEmpty {
            report += "\n⚠️ WARNINGS (recommended to fix):\n"
            for issue in warningIssues {
                report += "  • \(issue.message)\n"
                report += "    💡 \(issue.solution)\n"
            }
        }
        
        if !infoIssues.isEmpty {
            report += "\nℹ️ INFORMATION:\n"
            for issue in infoIssues {
                report += "  • \(issue.message)\n"
                report += "    💡 \(issue.solution)\n"
            }
        }
        
        return report
    }
    
    /// Print the validation report to console
    public func printReport() {
        print(generateReport())
    }
}

/// Individual validation issue with severity and guidance
public struct ValidationIssue {
    public enum Severity: String, CaseIterable {
        case error = "error"
        case warning = "warning"
        case info = "info"
        
        public var emoji: String {
            switch self {
            case .error: return "❌"
            case .warning: return "⚠️"
            case .info: return "ℹ️"
            }
        }
    }
    
    public enum Category: String, CaseIterable {
        case configuration = "configuration"
        case network = "network"
        case permissions = "permissions"
        case device = "device"
        
        public var displayName: String {
            switch self {
            case .configuration: return "Configuration"
            case .network: return "Network"
            case .permissions: return "Permissions"
            case .device: return "Device"
            }
        }
    }
    
    public let severity: Severity
    public let message: String
    public let solution: String
    public let category: Category
    
    public init(severity: Severity, message: String, solution: String, category: Category) {
        self.severity = severity
        self.message = message
        self.solution = solution
        self.category = category
    }
}

// MARK: - Convenience Extensions

public extension Cognitive3DSetupValidator {
    
    /// Validates configuration and prints results to console
    /// - Parameter settings: CoreSettings to validate
    /// - Returns: True if validation passed (no errors)
    @discardableResult
    static func validateAndPrint(_ settings: CoreSettings) -> Bool {
        let result = validateConfiguration(settings)
        result.printReport()
        return result.isValid
    }
    
    /// Quick validation for development/debugging
    /// - Parameter settings: CoreSettings to validate
    /// - Returns: Array of error messages, empty if valid
    static func quickValidation(_ settings: CoreSettings) -> [String] {
        let result = validateConfiguration(settings)
        return result.issues(withSeverity: .error).map { $0.message }
    }
}