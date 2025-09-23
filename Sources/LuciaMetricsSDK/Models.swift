//
//  Models.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//

import UIKit
import CommonCrypto

// Top-level struct representing the entire JSON
struct MetricsPayload: Codable, @unchecked Sendable {
	let data: DataObject
	let redirectHash: String
	let browserData: BrowserData
	let user: User
	let walletData: WalletData

	enum CodingKeys: String, CodingKey {
		case data, user
		case walletData = "wallet_data"
		case browserData = "browser_data"
		case redirectHash = "redirect_hash"
	}
}

// Nested struct for "data"
struct DataObject: Codable {
	let browser: Browser
	let device: Device
	let permissions: Permissions
	let screen: Screen
	let storage: Storage
}

// Nested struct for "data.browser"
struct Browser: Codable {
	let applePayAvailable: Bool
	let colorGamut: [String]  // Assuming strings; adjust if it's another type (e.g., [Int])
	let encoding: String
	let language: String
	let pluginsLength: Int
	let timezone: Int
	let uniqueHash: String
}

// Nested struct for "data.device"
struct Device: Codable {
	let cores: Int
	let cpuClass: String
	let memory: Int
	let touch: Bool
}

// Empty struct for "data.permissions" (handles empty object {})
struct Permissions: Codable {}

// Nested struct for "data.screen"
struct Screen: Codable {
	let availHeight: Int
	let availWidth: Int
	let colorDepth: Int
	let height: Int
	let orientation: Orientation
	let width: Int
}

// Nested struct for "data.screen.orientation"
struct Orientation: Codable {
	let angle: Int
	let type: String
}

// Nested struct for "data.storage"
struct Storage: Codable {
	let indexedDB: Bool
	let localStorage: Bool
}

// Nested struct for "browser_data"
struct BrowserData: Codable {
	let hash: String
	let id: String
	let timestamp: Timestamp
}

// Empty struct for "browser_data.timestamp" (handles empty object {})
struct Timestamp: Codable {}

// Nested struct for "user"
struct User: Codable {
	let userName: String

	enum CodingKeys: String, CodingKey {
		case userName = "user_name"
	}
}

// Empty struct for "wallet_data" (handles empty object {})
struct WalletData: Codable {}


struct AppInformation: Codable {
	let lid: String
	let appName: String
	let appVersion: String
	let appBuild: String
}

struct AnyCodable: Codable, @unchecked Sendable {
	let value: Any

	init(_ value: Any) { self.value = value }

	init(from decoder: Decoder) throws {
		// Not used in this context; implement if you need decoding
		throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Not implemented"))
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch value {
		case let v as String: try container.encode(v)
		case let v as Int: try container.encode(v)
		case let v as Double: try container.encode(v)
		case let v as Bool: try container.encode(v)
		case let v as [String: Any]: try container.encode(v.mapValues { AnyCodable($0) })
		case let v as [Any]: try container.encode(v.map { AnyCodable($0) })
		default: try container.encodeNil()
		}
	}
}

extension String {
	/// SHA256 hex string
	func sha256Hex() -> String? {
		guard let data = self.data(using: .utf8) else { return nil }
		var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		data.withUnsafeBytes {
			_ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
		}
		return hash.map { String(format: "%02x", $0) }.joined()
	}
}

extension UIApplication {

	static func generateUserAgent(appName: String, appVersion: String, buildNumber: String) -> String {
		let device = UIDevice.current
		let osName = device.systemName  // e.g., "iOS"
		let osVersion = device.systemVersion  // e.g., "17.0"
		let model = device.model  // e.g., "iPhone"
		let locale = Locale.current.identifier  // e.g., "en_US"
		let scale = UIScreen.main.scale  // e.g., 3.0 for Retina

		return "\(appName)/\(appVersion) (\(model); \(osName) \(osVersion); Scale/\(scale)) (Build/\(buildNumber); \(locale))"
	}

	// Helper: device memory (bytes)
	private static func sysMemSize() -> UInt64 {
		var mem: UInt64 = 0
		var size = MemoryLayout<UInt64>.size
		var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
		sysctl(&mib, UInt32(mib.count), &mem, &size, nil, 0)
		return mem
	}

	private static func getSysctlString(forKey key: String) -> String? {
		var size = 0
		sysctlbyname(key, nil, &size, nil, 0)
		var result = [CChar](repeating: 0, count: size)
		sysctlbyname(key, &result, &size, nil, 0)
		return String(cString: result)
	}

	private static func getCPUName() -> String {
		let machine = getSysctlString(forKey: "hw.machine") // e.g., "iPhone15,3"
		let cpuType = getSysctlString(forKey: "hw.cputype") // e.g., "16777228" (raw value for ARM64)
		let cpuSubtype = getSysctlString(forKey: "hw.cpusubtype")

		return "\(String(describing: cpuType)) \(String(describing: cpuSubtype))"
	}

	static func createMetrics(appInfo: AppInformation) -> MetricsPayload {

		// Some Constants that will be dynamic in the future
		let redirectHash = "iOS_TEST_USER_001_001"
		let uniqueHash = "iOS_Test_001_001"
		let userName = "iOSTestUser"
		let hash = "iOSTest"

		// Gather device info
		let device = UIDevice.current
		let screen = UIScreen.main
		let processInfo = ProcessInfo.processInfo

		let osName = device.systemName // "iOS"
		let osVersion = device.systemVersion
		let model = device.model
		let locale = Locale.current.identifier
		let scale = screen.scale

		// User-Agent matching iOS Safari style
		let userAgent = generateUserAgent(appName: appInfo.appName, appVersion: appInfo.appVersion, buildNumber: appInfo.appBuild)

		// OS string for body
		let osString = "\(osName) \(osVersion)|\(userAgent)"
		let touch = true

		// Memory in GB
		let memBytes = sysMemSize() // helper
		let memoryGB = Int(Double(memBytes) / 1_073_741_824.0)

		let cores = processInfo.activeProcessorCount
		let language = Locale.preferredLanguages.first ?? "en-US"
		let devicePixelRatio = Float(scale)
		let timezoneHours = TimeZone.current.secondsFromGMT() / 3600

		// Screen
		let screenWidth = Int(round(screen.bounds.width))
		let screenHeight = Int(round(screen.bounds.height))
		let availWidth = screenWidth
		let availHeight = screenHeight

		// Orientation
		var screenOrientationType = "portrait-primary"
		var screenOrientationAngle = 0
		switch device.orientation {
		case .landscapeLeft, .landscapeRight:
			screenOrientationType = "landscape-primary"
			screenOrientationAngle = 90
		case .portraitUpsideDown:
			screenOrientationType = "portrait-secondary"
			screenOrientationAngle = 180
		default: break
		}

		// Color depth
		let colorDepth = screen.traitCollection.displayGamut == .P3 ? 30 : 24

		let deviceInfo: Device = .init(cores: cores, cpuClass: getCPUName(), memory: memoryGB, touch: touch)
		let orientationInfo: Orientation = .init(angle: screenOrientationAngle, type: screenOrientationType)
		let screenInfo: Screen = .init(availHeight: availHeight, availWidth: availWidth, colorDepth: colorDepth, height: screenHeight, orientation: orientationInfo, width: screenWidth)
		let permissionInfo: Permissions = .init() // Empty for now
		let browserInfo: Browser = .init(applePayAvailable: false, colorGamut: [], encoding: "UTF-8", language: language, pluginsLength: 0, timezone: timezoneHours, uniqueHash: uniqueHash)
		let storageInfo: Storage = .init(indexedDB: false, localStorage: false)
		let payload: DataObject = .init(browser: browserInfo, device: deviceInfo, permissions: permissionInfo, screen: screenInfo, storage: storageInfo)
		let browserData: BrowserData = .init(hash: hash, id: appInfo.lid, timestamp: .init())
		let userInfo: User = .init(userName: userName)

		return .init(data: payload, redirectHash: redirectHash, browserData: browserData, user: userInfo, walletData: .init())
	}
}



