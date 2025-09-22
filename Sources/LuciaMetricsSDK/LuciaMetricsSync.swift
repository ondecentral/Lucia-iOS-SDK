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

public struct MetricsConfig: Sendable {
	let baseURL: String
	let apiKey: String

	public init(baseURL: String, apiKey: String) {
		self.baseURL = baseURL
		self.apiKey = apiKey
	}
}

public enum MetricsEnvironment {
	case test
	case staging
	case prod

	public var config: MetricsConfig {
		switch self {
		case .test:
			return .init(baseURL: "https://33e5e8c63065.ngrok-free.app", apiKey: "d05e2a71-1d5a484a-30698220-65292c18-93cb4d4a-ae634e6b-9d4a5151-08e8a244")
		default:
			return .init(baseURL: "https://staging.api.clickinsights.xyz", apiKey: "d05e2a71-1d5a484a-30698220-65292c18-93cb4d4a-ae634e6b-9d4a5151-08e8a244")
		}
	}
}

@MainActor
final class MetricsSyncer {

	let versionNumber: String
	let buildNumber: String
	let appName: String
	let config: MetricsConfig
	var userFingerprint: String

	init(
		versionNumber: String,
		buildNumber: String,
		appName: String,
		fingerprint: String,
		config: MetricsConfig = MetricsEnvironment.staging.config
	) {
		self.versionNumber = versionNumber
		self.buildNumber = buildNumber
		self.appName = appName
		self.userFingerprint = fingerprint
		self.config = config
	}

	private var baseURL: String {
		config.baseURL
	}

	private var apiKey: String {
		config.apiKey
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
		guard let url = URL(string: baseURL + "/api/sdk/init") else {
			completion(nil, NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
			return
		}

		let userAgent = UIApplication.generateUserAgent(appName: appName, appVersion: versionNumber, buildNumber: buildNumber)

		// Request
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
		request.setValue("*/*", forHTTPHeaderField: "Accept")
		request.httpBody = httpBody

		let key = self.lidKey

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				completion(nil, error)
				return
			}
			guard let data = data else {
				completion(nil, NSError(domain: "ResponseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
				return
			}

			guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
				print("Data could not be converted to JSON: \(String(describing: String(data: data, encoding: .utf8)))")
				completion(nil, NSError(domain: "ResponseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
				return
			}

			print("JSON response: \(json)")

			guard let responseLID = json["lid"] as? String else {
				completion(nil, NSError(domain: "ResponseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No device finger print"]))
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

