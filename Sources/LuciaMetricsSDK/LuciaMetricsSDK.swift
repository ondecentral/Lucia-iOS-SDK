// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import AdSupport  // For IDFA
import AppTrackingTransparency  // For iOS 14+ tracking permission (import if targeting iOS 14+)

public enum MetricKeys: String {
	case deviceId = "device_id"
	case idfv = "idfv"
	case ipAddress = "ip_address"
	case deviceModel = "device_model"
	case osVersion = "os_version"
}

public typealias DeviceMetrics = [String: String]

public extension DeviceMetrics {
	var fingerprint: String {
		let idfv = self[MetricKeys.idfv.rawValue] ?? "unknown"
		let deviceId = self[MetricKeys.deviceId.rawValue] ?? "unknown"
		return "\(idfv)-\(deviceId)"
	}
}


// Enum for potential errors
public enum MetricsError: Error {
	case permissionDenied
	case networkUnavailable
	case unknown
}

public class MetricsCollector {

	// Singleton for easy access (optional; you could make it non-singleton)
	nonisolated(unsafe) public static let shared = MetricsCollector()

	private init() {}  // Prevent multiple instances

	// Request tracking permission (required for IDFA on iOS 14+)
	public func requestTrackingPermission(completion: @escaping (Bool) -> Void) {
		if #available(iOS 14, *) {
			ATTrackingManager.requestTrackingAuthorization { status in
				completion(status == .authorized)
			}
		} else {
			completion(true)  // Pre-iOS 14, assume allowed
		}
	}

	// Get the IDFA
	private func getIDFA() -> String? {
		// Check whether advertising tracking is enabled
		if #available(iOS 14, *) {
			if ATTrackingManager.trackingAuthorizationStatus != ATTrackingManager.AuthorizationStatus.authorized  {
				return nil
			}
		} else {
			if ASIdentifierManager.shared().isAdvertisingTrackingEnabled == false {
				return nil
			}
		}

		return ASIdentifierManager.shared().advertisingIdentifier.uuidString
	}

	// Get device identifier (alternative to MAC address)
	@MainActor public func getDeviceIdentifier() throws -> String {
		// Option 1: Vendor Identifier (resets if app is uninstalled)
		if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
			return vendorID
		}

		// Option 2: Advertising Identifier (IDFA) - requires permission
		if let ifda = getIDFA() {
			return ifda
		}

		throw MetricsError.permissionDenied
	}

	// Get IP address (IPv4 for the primary interface)
	public func getIPAddress() throws -> String {
		var address: String?
		var ifaddr: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&ifaddr) == 0 else {
			throw MetricsError.networkUnavailable
		}

		var ptr = ifaddr
		while ptr != nil {
			defer { ptr = ptr?.pointee.ifa_next }

			let interface = String(cString: ptr!.pointee.ifa_name)
			let flags = Int32(ptr!.pointee.ifa_flags)
			var addr = ptr?.pointee.ifa_addr.pointee

			if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) &&
				addr?.sa_family == UInt8(AF_INET) {  // IPv4 only for simplicity

				if interface == "en0" || interface == "pdp_ip0" {  // Wi-Fi or Cellular
					var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
					getnameinfo(&addr!, socklen_t(addr!.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)

					// Convert to String by taking bytes up to the null terminator and decoding as UTF-8
					let bytes = hostname.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
					address = String(decoding: bytes, as: UTF8.self)

					break
				}
			}
		}

		freeifaddrs(ifaddr)

		guard let ip = address else {
			throw MetricsError.unknown
		}

		return ip
	}

	// Example method to collect and return metrics as a dictionary
	@MainActor public func collectMetrics() throws -> DeviceMetrics {
		var metrics: [String: String] = [:]

		// Add device ID
		metrics[MetricKeys.deviceId.rawValue] = try getDeviceIdentifier()

		// Add IDFV
		let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
		metrics[MetricKeys.idfv.rawValue] = idfv

		// Add IP address
		metrics[MetricKeys.ipAddress.rawValue] = try getIPAddress()

		// Optional: Add more metrics (e.g., device model)
		metrics[MetricKeys.deviceModel.rawValue] = UIDevice.current.model
		metrics[MetricKeys.osVersion.rawValue] = UIDevice.current.systemVersion

		return metrics
	}
}
