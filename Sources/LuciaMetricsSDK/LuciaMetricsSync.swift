//
//  LuciaMetricsSync.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 9/17/25.
//


import UIKit
import Foundation

struct MetricsConfig: Sendable {
	let baseURL: String
	let apiKey: String

	public init(baseURL: String, apiKey: String) {
		self.baseURL = baseURL
		self.apiKey = apiKey
	}
}

public enum MetricsEnvironment {
	case develop(url: String) // To be removed on production
	case test
	case staging
	case prod

	private var apiKey: String {
		if let apiKey = Bundle.main.infoDictionary?["LuciaSDKKey"] as? String {
			return apiKey
		} else {
			return ""
		}
	}

	var config: MetricsConfig {
		switch self {
		case .test:
			return .init(baseURL: "https://33e5e8c63065.ngrok-free.app", apiKey: apiKey)
		case .develop(let url):
			return .init(baseURL: url, apiKey: apiKey)
		default:
			return .init(baseURL: "https://staging.api.clickinsights.xyz", apiKey: apiKey)
		}
	}
}

@MainActor
final class MetricsSyncer {

	let versionNumber: String
	let buildNumber: String
	let appName: String
	let userName: String?
	private let config: MetricsConfig
	var userFingerprint: String

	init(
		versionNumber: String,
		buildNumber: String,
		appName: String,
		userName: String? = nil,
		fingerprint: String,
		environment: MetricsEnvironment = MetricsEnvironment.staging
	) {
		self.versionNumber = versionNumber
		self.buildNumber = buildNumber
		self.appName = appName
		self.userFingerprint = fingerprint
		self.userName = userName
		self.config = environment.config
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

		let payloadInfo: AppInformation = .init(lid: userFingerprint, userName: userName, appName: appName, appVersion: versionNumber, appBuild: buildNumber, sessionId: "", sessionHash: "")
		let payloadBody = UIApplication.createMetrics(appInfo: payloadInfo)

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

			guard let session = json["session"] as? [String: Any] else {
				return
			}

			let sessionID: String = session["id"] as? String ?? ""
			let sessionHash: String = session["hash"] as? String ?? ""

			print("Session: \(sessionID) and hash: \(sessionHash)")

			let appInfo: AppInformation = .init(lid: responseLID, userName: self.userName, appName: self.appName, appVersion: self.versionNumber, appBuild: self.buildNumber, sessionId: sessionID, sessionHash: sessionHash)

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

