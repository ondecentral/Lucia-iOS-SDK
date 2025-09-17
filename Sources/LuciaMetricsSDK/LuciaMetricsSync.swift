//
//  LuciaMetricsSync.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//


import UIKit
import Foundation
import CommonCrypto // For SHA256 hashing, if needed for uniqueHash

// Note: This code assumes it's running on an iOS device (not simulator for accurate device info).
// It collects device information similar to the web request and sends a POST to the API.
// The base URL is configurable.
// The User-Agent is dynamically generated to match the iOS device and OS.
// The 'lid' is persisted in UserDefaults (similar to localStorage).
// For 'uniqueHash', I've implemented a simple SHA256 hash of concatenated device info (as a fingerprint).
// Adjust as needed if the exact hashing logic is known.
// Memory is fetched via sysctl (total physical RAM in GB, rounded to integer).
// Plugins are set to 0/empty since not applicable on iOS.
// Other fields are adapted to iOS equivalents.


@MainActor private func generateUserAgent(appName: String, appVersion: String, buildNumber: String) -> String {
	let device = UIDevice.current
	let osName = device.systemName  // e.g., "iOS"
	let osVersion = device.systemVersion  // e.g., "17.0"
	let model = device.model  // e.g., "iPhone"
	let locale = Locale.current.identifier  // e.g., "en_US"
	let scale = UIScreen.main.scale  // e.g., 3.0 for Retina

	return "\(appName)/\(appVersion) (\(model); \(osName) \(osVersion); Scale/\(scale)) (Build/\(buildNumber); \(locale))"
}

@MainActor func initializeSDK(baseURLString: String = "https://api.clickinsights.xyz", apiKey: String = "d05e2a71-1d5a484a-30698220-65292c18-93cb4d4a-ae634e6b-9d4a5151-08e8a244", completion: @escaping (String?, Error?) -> Void) {
	// Get or generate LID (similar to localStorage)
	let userDefaults = UserDefaults.standard
	var lid = userDefaults.string(forKey: "sdk_lid")
	if lid == nil {
		lid = UUID().uuidString
		userDefaults.set(lid, forKey: "sdk_lid")
	}

	// Collect device info
	let device = UIDevice.current
	let screen = UIScreen.main
	let processInfo = ProcessInfo.processInfo

	let osName = device.systemName // e.g., "iOS"
	let osVersion = device.systemVersion // e.g., "17.0"
	let model = device.model // e.g., "iPhone"

	// Generate User-Agent string matching iOS Safari format
	let userAgent = generateUserAgent(appName: "'", appVersion: "", buildNumber: "")

	// OS string for body (adapted from example)
	let osString = "\(osName) \(osVersion)|\(userAgent)"

	// Touch support: true for iOS devices
	let touch = true

	// Memory: Total physical RAM in GB (integer)
	var memory: Int = 0
	var size: size_t = MemoryLayout<UInt64>.size
	var memSize: UInt64 = 0
	let mib: [Int32] = [CTL_HW, HW_MEMSIZE]
	sysctl(UnsafeMutablePointer(mutating: mib), 2, &memSize, &size, nil, 0)
	memory = Int(Double(memSize) / 1_073_741_824.0) // Convert bytes to GB, round to int

	// Cores: Active processor count
	let cores = processInfo.activeProcessorCount

	// Language: Preferred language
	let language = Locale.preferredLanguages.first ?? "en-US"

	// Device pixel ratio (scale)
	let devicePixelRatio = Float(screen.scale)

	// Timezone offset in hours
	let timezone = TimeZone.current.secondsFromGMT() / 3600

	// Plugins: Not applicable on iOS
	let pluginsLength = 0
	let pluginNames: [String] = []

	// Screen dimensions (in points, similar to CSS pixels in browser)
	let screenWidth = Int(screen.bounds.width)
	let screenHeight = Int(screen.bounds.height)
	let availWidth = screenWidth // On iOS, avail is typically full screen
	let availHeight = screenHeight

	// Screen orientation
	var screenOrientationType = "portrait-primary"
	var screenOrientationAngle = 0
	switch device.orientation {
	case .landscapeLeft, .landscapeRight:
		screenOrientationType = "landscape-primary"
		screenOrientationAngle = 90
	case .portraitUpsideDown:
		screenOrientationType = "portrait-secondary"
		screenOrientationAngle = 180
	default:
		break // Default to portrait-primary, angle 0
	}

	// Color depth: Approximate based on display gamut (24 for sRGB, 30 for P3)
	let colorDepth = screen.traitCollection.displayGamut == .P3 ? 30 : 24

	// Unique hash: SHA256 of concatenated device info (as a fingerprint example; adjust if needed)
	let hashInput = "\(userAgent)\(osVersion)\(language)\(screenWidth)\(screenHeight)\(memory)\(cores)\(devicePixelRatio)\(timezone)"
	let uniqueHash = sha256(string: hashInput) ?? "placeholder_hash"

	// Build the nested JSON structure
	let innerData: [String: Any] = [
		"isMetaMaskInstalled": false, // Not applicable on iOS
		"os": osString,
		"touch": touch,
		"memory": memory,
		"agent": userAgent,
		"cores": cores,
		"language": language,
		"devicePixelRatio": devicePixelRatio,
		"timezone": timezone,
		"pluginsLength": pluginsLength,
		"pluginNames": pluginNames,
		"screenWidth": screenWidth,
		"screenheight": screenHeight, // Note: Typo in original example, kept as-is
		"availHeight": availHeight,
		"availWidth": availWidth,
		"screenOrientationType": screenOrientationType,
		"screenOrientationAngle": screenOrientationAngle,
		"uniqueHash": uniqueHash,
		"colorDepth": colorDepth,
		"indexedDB": [:] as [String: Any], // Empty dict
		"localStorage": ["lid": lid ?? ""]
	]

	let body: [String: Any?] = [
		"user": [
			"name": nil,
			"data": [
				"redirectHash": "",
				"data": innerData
			]
		],
		"session": nil,
		"utm": nil
	]

	// Serialize to JSON data
	guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
		completion(nil, NSError(domain: "JSONError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"]))
		return
	}

	// Build URLRequest
	guard let url = URL(string: baseURLString + "/api/sdk/init") else {
		completion(nil, NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
		return
	}
	var request = URLRequest(url: url)
	request.httpMethod = "POST"
	request.setValue("application/json", forHTTPHeaderField: "Content-Type")
	request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
	request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
	request.setValue("*/*", forHTTPHeaderField: "Accept") // From the request log
	// Optional: Add other headers if needed to mimic the web request (e.g., Origin, Referer)
	// request.setValue("https://www.yourapp.com", forHTTPHeaderField: "Origin")
	// request.setValue("https://www.yourapp.com/", forHTTPHeaderField: "Referer")
	request.httpBody = httpBody

	// Send request
	let task = URLSession.shared.dataTask(with: request) { data, response, error in
		if let error = error {
			completion(nil, error)
			return
		}

		guard let data = data,
			  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
			  let responseLID = json["lid"] else {
			completion(nil, NSError(domain: "ResponseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
			return
		}

		// Optionally update stored LID if server returns a different one
		if responseLID != lid {
			userDefaults.set(responseLID, forKey: "sdk_lid")
		}

		completion(responseLID, nil)
	}
	task.resume()
}

// Helper function for SHA256 hashing
func sha256(string: String) -> String? {
	guard let data = string.data(using: .utf8) else { return nil }
	var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
	data.withUnsafeBytes {
		_ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
	}
	return hash.map { String(format: "%02x", $0) }.joined()
}

// Example usage:
// initializeSDK() { lid, error in
//     if let lid = lid {
//         print("Initialized with LID: \(lid)")
//     } else {
//         print("Error: \(error?.localizedDescription ?? "Unknown")")
//     }
// }

