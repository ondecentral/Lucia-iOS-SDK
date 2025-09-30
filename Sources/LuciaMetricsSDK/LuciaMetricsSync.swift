//
//  LuciaMetricsSync.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//


import UIKit
import Foundation

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
	let userName: String?
	let config: MetricsConfig
	var userFingerprint: String

	init(
		versionNumber: String,
		buildNumber: String,
		appName: String,
		userName: String? = nil,
		fingerprint: String,
		config: MetricsConfig = MetricsEnvironment.staging.config
	) {
		self.versionNumber = versionNumber
		self.buildNumber = buildNumber
		self.appName = appName
		self.userFingerprint = fingerprint
		self.userName = userName
		self.config = config
	}

	private var baseURL: String {
		config.baseURL
	}

	private var configApiKey: String {
		config.apiKey
	}

	// Internal storage key
	private let lidKey = "user_unique_fingerprint_key"

	func initializeSDK(baseURLString: String? = nil,
					   completion: @escaping @Sendable (String?, Error?) -> Void) {
		// Check for previously saved App Information
		if let previouslySavedAppInformation = UserDefaults.standard.loadAppInformation() {
			completion(previouslySavedAppInformation.lid, nil)
			return
		}
		
		let appInfo: AppInformation = .init(lid: userFingerprint, userName: userName, appName: appName, appVersion: versionNumber, appBuild: buildNumber)
		let payloadBody = UIApplication.createMetrics(appInfo: appInfo)

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
		request.setValue(configApiKey, forHTTPHeaderField: "X-API-KEY")
		request.setValue("iOS-1.0.0", forHTTPHeaderField: "sdk-version")
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

			// Save for next time 
			UserDefaults.standard.saveAppInformation(appInfo)
		}
		task.resume()

	}

	@available(iOS 15.0, *)
	func initializeSDK(baseURLString: String? = nil) async throws -> String {
		try await withCheckedThrowingContinuation { cont in
			initializeSDK(baseURLString: baseURLString) { lid, error in
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

