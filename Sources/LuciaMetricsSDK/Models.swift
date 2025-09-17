//
//  Models.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//

import UIKit
import CommonCrypto

struct AppInformation: Codable {
	let lid: String
	let appName: String
	let appVersion: String
	let appBuild: String
}

struct InitPayloadData: Codable, Sendable {
	let isMetaMaskInstalled: Bool
	let os: String
	let touch: Bool
	let memory: Int
	let agent: String
	let cores: Int
	let language: String
	let devicePixelRatio: Float
	let timezone: Int
	let pluginsLength: Int
	let pluginNames: [String]
	let screenWidth: Int
	let screenheight: Int
	let availHeight: Int
	let availWidth: Int
	let screenOrientationType: String
	let screenOrientationAngle: Int
	let uniqueHash: String
	let colorDepth: Int
	let indexedDB: [String: AnyCodable]
	let localStorage: [String: String]
}

struct InitPayloadUserData: Codable {
	let redirectHash: String
	let data: InitPayloadData
}

struct InitPayloadUser: Codable {
	let name: String?
	let data: InitPayloadUserData
}

struct InitPayloadBody: Codable {
	let user: InitPayloadUser
	let session: String?
	let utm: String?
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

	static func createMetrics(appInfo: AppInformation) -> InitPayloadData {

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

		// Plugins
		let pluginsLength = 0
		let pluginNames: [String] = []

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

		// Unique hash
		// What am I supposed to hash ?
		let hashInput = "\(userAgent)\(osVersion)\(language)\(screenWidth)\(screenHeight)\(memoryGB)\(cores)\(devicePixelRatio)\(timezoneHours)"
		let uniqueHash = hashInput.sha256Hex() ?? "placeholder_hash"

		return .init(
			isMetaMaskInstalled: false,
			os: osString,
			touch: touch,
			memory: memoryGB,
			agent: userAgent,
			cores: cores,
			language: language,
			devicePixelRatio: devicePixelRatio,
			timezone: timezoneHours,
			pluginsLength: pluginsLength,
			pluginNames: pluginNames,
			screenWidth: screenWidth,
			screenheight: screenHeight,
			availHeight: availHeight,
			availWidth: availWidth,
			screenOrientationType: screenOrientationType,
			screenOrientationAngle: screenOrientationAngle,
			uniqueHash: uniqueHash,
			colorDepth: colorDepth,
			indexedDB: [:],
			localStorage: ["lid": appInfo.lid]
		)
	}
}



