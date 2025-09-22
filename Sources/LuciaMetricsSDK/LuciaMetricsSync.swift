//
//  LuciaMetricsSync.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//


import UIKit
import Foundation

// Example usage:
// initializeSDK() { lid, error in
//     if let lid = lid {
//         print("Initialized with LID: \(lid)")
//     } else {
//         print("Error: \(error?.localizedDescription ?? "Unknown")")
//     }
// }

@MainActor
final class MetricsSyncer {

	private let defaultBaseURL = "https://staging.api.clickinsights.xyz"
	private let defaultApiKey = "05e2a71-1d5a484a-30698220-65292c18-93cb4d4a-ae634e6b-9d4a5151-08e8a244"

	let versionNumber: String
	let buildNumber: String
	let appName: String
	var userFingerprint: String

	init(versionNumber: String, buildNumber: String, appName: String, fingerprint: String) {
		self.versionNumber = versionNumber
		self.buildNumber = buildNumber
		self.appName = appName
		self.userFingerprint = fingerprint
	}

	// Internal storage key
	private let lidKey = "user_unique_fingerprint_key"

	func initializeSDK(baseURLString: String? = nil,
					   apiKey: String? = nil,
					   completion: @escaping @Sendable (String?, Error?) -> Void) {
		let appInfo: AppInformation = .init(lid: userFingerprint, appName: appName, appVersion: versionNumber, appBuild: buildNumber)
		let payloadData = UIApplication.createMetrics(appInfo: appInfo)
		let payloadBody: InitPayloadBody = .init(user: .init(name: nil, data: .init(redirectHash: "", data: payloadData)), session: nil, utm: nil)

		// Serialize JSON
		guard let httpBody = try? JSONEncoder().encode(payloadBody) else {
			completion(nil, NSError(domain: "JSONError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"]))
			return
		}

		// URL
		guard let url = URL(string: defaultBaseURL + "/api/sdk/init") else {
			completion(nil, NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
			return
		}

		let userAgent = UIApplication.generateUserAgent(appName: appName, appVersion: versionNumber, buildNumber: buildNumber)

		// Request
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		request.setValue(defaultApiKey, forHTTPHeaderField: "X-API-KEY")
		request.setValue("*/*", forHTTPHeaderField: "Accept")
		request.httpBody = httpBody

		let key = self.lidKey

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				completion(nil, error)
				return
			}
			guard
				let data = data,
				let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
				let responseLID = json["lid"] as? String
			else {
				completion(nil, NSError(domain: "ResponseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
				return
			}

			UserDefaults.standard.set(responseLID, forKey: key)
			completion(responseLID, nil)
		}
		task.resume()

	}

	@available(iOS 15.0, *)
	func initializeSDK(baseURLString: String? = nil,
					   apiKey: String? = nil) async throws -> String {
		try await withCheckedThrowingContinuation { cont in
			initializeSDK(baseURLString: baseURLString, apiKey: apiKey) { lid, error in
				if let error = error {
					cont.resume(throwing: error)
				} else if let lid = lid {
					cont.resume(returning: lid)
				} else {
					cont.resume(throwing: NSError(domain: "Unknown", code: 0, userInfo: nil))
				}
			}
		}
	}
}

