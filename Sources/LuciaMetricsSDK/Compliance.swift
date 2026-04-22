//
//  Compliance.swift
//  LuciaMetricsSDK
//
//  Tiered data collection, consent receipt logging, and at-rest encryption
//  helpers introduced to address the April 4, 2026 compliance audit.
//

import Foundation
import CryptoKit

// MARK: - Tiered Data Collection

/// Controls what categories of data the SDK is permitted to collect.
///
/// Per legal counsel (Kat Esquire, 2026-03-24) the SDK must support configurable
/// tiers so clients can opt into the minimum amount of processing required for
/// their use case. This enforces GDPR Art. 5(1)(c) data minimization.
public enum DataCollectionTier: Int, Codable, Sendable {
	/// Minimal identifiers + coarse device model/OS only. No IP, no touch events,
	/// no extended device attributes.
	case tier1Metrics = 1
	/// Tier 1 + touch event telemetry.
	case tier2MetricsAndTouch = 2
	/// Tier 2 + IP address and full device attribute payload (requires explicit
	/// consent and a signed DPA).
	case tier3Full = 3

	var allowsTouchEvents: Bool { self.rawValue >= 2 }
	var allowsIPAddress: Bool { self.rawValue >= 3 }
	var allowsExtendedDeviceAttributes: Bool { self.rawValue >= 3 }
}

// MARK: - Consent Receipt

/// Immutable record of a user's tracking consent. GDPR requires demonstrable
/// proof of consent (lawful basis), so every ATT decision is logged with the
/// active tier, scope, and timestamp.
public struct ConsentReceipt: Codable, Sendable {
	public enum ATTStatus: String, Codable, Sendable {
		case authorized
		case denied
		case restricted
		case notDetermined
		case preIOS14
	}

	public let id: UUID
	public let timestamp: Date
	public let tier: DataCollectionTier
	public let attStatus: ATTStatus
	/// Human-readable list of the data categories the user agreed to.
	public let scope: [String]
	public let sdkVersion: String
	public let appVersion: String

	public init(
		id: UUID = UUID(),
		timestamp: Date = Date(),
		tier: DataCollectionTier,
		attStatus: ATTStatus,
		scope: [String],
		sdkVersion: String,
		appVersion: String
	) {
		self.id = id
		self.timestamp = timestamp
		self.tier = tier
		self.attStatus = attStatus
		self.scope = scope
		self.sdkVersion = sdkVersion
		self.appVersion = appVersion
	}
}

// MARK: - Compliance Manager

/// Central holder for the active tier and consent receipts. Thread-safe via an
/// internal lock so the singleton can be read from any actor context.
public final class ComplianceManager: @unchecked Sendable {
	public static let shared = ComplianceManager()

	private let lock = NSLock()
	private var _tier: DataCollectionTier = .tier1Metrics

	private init() {
		if let raw = UserDefaults.standard.object(forKey: Keys.tier) as? Int,
		   let stored = DataCollectionTier(rawValue: raw) {
			_tier = stored
		}
	}

	public var tier: DataCollectionTier {
		lock.lock(); defer { lock.unlock() }
		return _tier
	}

	/// Set the active collection tier. Persisted across app launches.
	public func setTier(_ tier: DataCollectionTier) {
		lock.lock(); _tier = tier; lock.unlock()
		UserDefaults.standard.set(tier.rawValue, forKey: Keys.tier)
	}

	// MARK: Consent Receipts

	/// Persist a consent receipt. Appends to the local audit log and never
	/// mutates existing entries.
	public func recordConsent(_ receipt: ConsentReceipt) {
		var log = loadConsentLog()
		log.append(receipt)
		saveConsentLog(log)
	}

	public func loadConsentLog() -> [ConsentReceipt] {
		guard let data = UserDefaults.standard.data(forKey: Keys.consentLog) else { return [] }
		return (try? JSONDecoder().decode([ConsentReceipt].self, from: data)) ?? []
	}

	private func saveConsentLog(_ log: [ConsentReceipt]) {
		guard let data = try? JSONEncoder().encode(log) else { return }
		UserDefaults.standard.set(data, forKey: Keys.consentLog)
	}

	private enum Keys {
		static let tier = "luciaSDK.dataCollectionTier"
		static let consentLog = "luciaSDK.consentReceipts"
	}
}

// MARK: - At-Rest Encryption

/// AES-256-GCM helper used to encrypt touch event JSON on disk. A single
/// per-install key is generated lazily and stored in the Keychain so the data
/// cannot be read off-device without the original device's Keychain.
enum EventCipher {
	private static let keychainService = "xyz.clickinsights.lucia.sdk"
	private static let keychainAccount = "touchEventEncryptionKey"

	/// Encrypts `plaintext` with AES-GCM. Returns the combined sealed box
	/// (nonce + ciphertext + tag) ready to write to disk.
	static func encrypt(_ plaintext: Data) throws -> Data {
		let key = try loadOrCreateKey()
		let sealed = try AES.GCM.seal(plaintext, using: key)
		guard let combined = sealed.combined else {
			throw NSError(domain: "EventCipher", code: -1,
				userInfo: [NSLocalizedDescriptionKey: "Failed to serialize sealed box"])
		}
		return combined
	}

	static func decrypt(_ combined: Data) throws -> Data {
		let key = try loadOrCreateKey()
		let box = try AES.GCM.SealedBox(combined: combined)
		return try AES.GCM.open(box, using: key)
	}

	private static func loadOrCreateKey() throws -> SymmetricKey {
		if let existing = try readKeyFromKeychain() {
			return existing
		}
		let key = SymmetricKey(size: .bits256)
		try writeKeyToKeychain(key)
		return key
	}

	private static func readKeyFromKeychain() throws -> SymmetricKey? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: keychainService,
			kSecAttrAccount as String: keychainAccount,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		if status == errSecItemNotFound { return nil }
		guard status == errSecSuccess, let data = item as? Data else {
			throw NSError(domain: "EventCipher.Keychain", code: Int(status))
		}
		return SymmetricKey(data: data)
	}

	private static func writeKeyToKeychain(_ key: SymmetricKey) throws {
		let data = key.withUnsafeBytes { Data($0) }
		let attrs: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: keychainService,
			kSecAttrAccount as String: keychainAccount,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
			kSecValueData as String: data
		]
		let status = SecItemAdd(attrs as CFDictionary, nil)
		guard status == errSecSuccess || status == errSecDuplicateItem else {
			throw NSError(domain: "EventCipher.Keychain", code: Int(status))
		}
	}
}
