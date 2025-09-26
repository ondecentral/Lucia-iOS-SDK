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
	let redirectHash: String?
	let session: Session
	let user: User
	let walletData: WalletData
	let utm: UTM
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
	let language: String
	let pluginsLength: Int
	let pluginNames: [String]
	let timezone: Int
	let mobileId: String
	let uniqueHash: String
	let contrastPreference: String
}

// Nested struct for "data.device"
struct Device: Codable {
	let cores: Int
	let memory: Int
	let touch: Bool
	let devicePixelRatio: Float
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
struct Session: Codable {
	let hash: String
	let id: String
	let serverSessionId: String
	let timestamp: String
}

// Nested struct for "user"
struct User: Codable {
	let name: String?
}

// Empty struct for "wallet_data" (handles empty object {})
struct WalletData: Codable {}

struct UTM: Codable {}


struct AppInformation: Codable {
	let lid: String
	let userName: String?
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

	static func createMetrics(appInfo: AppInformation) -> MetricsPayload {

		// Some Constants that will be dynamic in the future
		let redirectHash: String? = nil
		let uniqueHash: String = appInfo.lid.sha256Hex() ?? ""
		let userName: String? = appInfo.userName

		// Session Id
		let sessionId = UUID().uuidString
		let sessionIdHash = sessionId.sha256Hex() ?? ""

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

		// current date
		let currentDate = Date()
		let timestamp = currentDate.timeIntervalSince1970

		let deviceInfo: Device = .init(cores: cores, memory: memoryGB, touch: touch, devicePixelRatio: devicePixelRatio)
		let orientationInfo: Orientation = .init(angle: screenOrientationAngle, type: screenOrientationType)
		let screenInfo: Screen = .init(availHeight: availHeight, availWidth: availWidth, colorDepth: colorDepth, height: screenHeight, orientation: orientationInfo, width: screenWidth)
		let permissionInfo: Permissions = .init() // Empty for now
		let browserInfo: Browser = .init(applePayAvailable: false, colorGamut: [], language: language, pluginsLength: 0, pluginNames: [], timezone: timezoneHours, mobileId: appInfo.lid, uniqueHash: uniqueHash, contrastPreference: "dark")
		let storageInfo: Storage = .init(indexedDB: false, localStorage: false)
		let payload: DataObject = .init(browser: browserInfo, device: deviceInfo, permissions: permissionInfo, screen: screenInfo, storage: storageInfo)
		let sessionData: Session = .init(hash: sessionIdHash, id: sessionId, serverSessionId: "", timestamp: String(timestamp))
		let userInfo: User = .init(name: userName)

		return .init(data: payload, redirectHash: redirectHash, session: sessionData, user: userInfo, walletData: .init(), utm: .init())
	}
}

extension UserDefaults {
	static let appInformationKey = "appInformation"

	/// Saves an AppInformation instance to UserDefaults.
	/// - Parameter info: The AppInformation struct to save.
	/// - Returns: True if saving was successful, false otherwise.
	func saveAppInformation(_ info: AppInformation) -> Bool {
		do {
			let encoder = JSONEncoder()
			let data = try encoder.encode(info)
			self.set(data, forKey: UserDefaults.appInformationKey)
			return true
		} catch {
			print("Error encoding AppInformation: \(error.localizedDescription)")
			return false
		}
	}

	/// Loads the saved AppInformation from UserDefaults.
	/// - Returns: The decoded AppInformation, or nil if loading fails (e.g., no data or decoding error).
	func loadAppInformation() -> AppInformation? {
		guard let data = self.data(forKey: UserDefaults.appInformationKey) else {
			print("No AppInformation data found in UserDefaults.")
			return nil
		}

		do {
			let decoder = JSONDecoder()
			let info = try decoder.decode(AppInformation.self, from: data)
			return info
		} catch {
			print("Error decoding AppInformation: \(error.localizedDescription)")
			return nil
		}
	}
}



