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
public enum MetricsError: Error, Sendable {
	case permissionDenied
	case networkUnavailable
	case syncFailed(error: Error)
	case unknown
}

extension MetricsEnvironment: @unchecked Sendable {}

public class MetricsCollector {

	// Singleton for easy access (optional; you could make it non-singleton)
	nonisolated(unsafe) public static let shared = MetricsCollector()

	private init() { }

	@MainActor public func captureDeviceFingerprint(
		versionNumber: String,
		buildNumber: String,
		appName: String,
		userName: String,
		environment: MetricsEnvironment = .staging,
		completion: @escaping @Sendable (Result<String, MetricsError>) -> Void)
	async {
		self.requestTrackingPermission { granted in
			if granted {
				do {
					Task { @MainActor in
						let metrics = try MetricsCollector.shared.collectMetrics()
						print("Collected Metrics: \(metrics)")
						// Send to your server or log them
						let fingerprint = metrics.fingerprint
						let syncer = MetricsSyncer(versionNumber: versionNumber, buildNumber: buildNumber, appName: appName, userName: userName, fingerprint: fingerprint, environment: environment)
						syncer.initializeSDK { fingerprint, error in
							if let error = error {
								let metricsError = MetricsError.syncFailed(error: error)
								completion(.failure(.syncFailed(error: metricsError)))
							} else if let lid = fingerprint {
								completion(.success(lid))
							} else {
								completion(.failure(.unknown))
							}
						}
					}
				}
			} else {
				completion(.failure(.permissionDenied))
			}
		}
	}

	// Request tracking permission (required for IDFA on iOS 14+)
	func requestTrackingPermission(completion: @escaping @Sendable (Bool) -> Void) {
		if #available(iOS 14, *) {
			ATTrackingManager.requestTrackingAuthorization { status in
				let isAuthorized: Bool = (status == .authorized)
				completion(isAuthorized)
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
	@MainActor func getDeviceIdentifier() throws -> String {
		// Option 2: Advertising Identifier (IDFA) - requires permission
		if let ifda = getIDFA() {
			return ifda
		}

		throw MetricsError.permissionDenied
	}

	// Get IP address (IPv4 for the primary interface)
	func getIPAddress() throws -> String {
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
