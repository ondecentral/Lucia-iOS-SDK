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

// MARK: - Region Policy

/// Region enforcement strategy. When a user is detected in a restricted
/// jurisdiction, the SDK will either disable itself entirely or clamp the
/// active tier down to Tier 1.
public enum RegionPolicy: String, Codable, Sendable {
	/// No region gating. Suitable only when the client has full GDPR/CCPA
	/// compliance infrastructure (DPAs, DPIAs, consent UI) in place.
	case allowAll
	/// In EU or California, force Tier 1 regardless of what the client requests.
	/// Outside those regions, honor the requested tier.
	case clampToTier1InRestrictedRegions
	/// In EU or California, disable the SDK entirely and surface an error to
	/// the client. Default for Phase 1 launch (non-EU, non-California markets).
	case disableInRestrictedRegions
}

/// Best-effort on-device region detector. Uses `Locale.current.regionCode` and
/// `TimeZone.current.identifier` — we intentionally do NOT call any IP
/// geolocation service to avoid making a network request before consent.
public enum RegionDetector {
	/// ISO-3166 country codes for the current EU member states. Checked against
	/// Locale.current.regionCode which is set from the user's Apple ID region.
	static let euRegionCodes: Set<String> = [
		"AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
		"GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
		"RO", "SK", "SI", "ES", "SE",
		// EEA non-EU that are covered by GDPR in practice
		"IS", "LI", "NO",
		// UK GDPR (post-Brexit but functionally equivalent)
		"GB"
	]

	/// California proxy: region US + Pacific timezone. Not perfect (covers
	/// Oregon/Washington/Nevada too) but errs on the side of MORE restriction,
	/// which is the safer failure mode for compliance.
	static func isLikelyCalifornia() -> Bool {
		let region = Locale.current.regionCode ?? ""
		guard region == "US" else { return false }
		let tz = TimeZone.current.identifier
		return tz == "America/Los_Angeles"
	}

	static func isEU() -> Bool {
		let region = Locale.current.regionCode ?? ""
		return euRegionCodes.contains(region)
	}

	public static func isRestrictedRegion() -> Bool {
		isEU() || isLikelyCalifornia()
	}
}

// MARK: - Data Minimization Overrides

/// Per-client overrides that further restrict what a given tier collects.
/// Fields listed in `excludedFields` are zeroed out even if the active tier
/// would otherwise allow them. Useful for clients whose DPA or legal review
/// excludes specific attributes (e.g. timezone, language).
public struct DataMinimizationOverrides: Codable, Sendable {
	public let excludedFields: Set<String>

	public init(excludedFields: Set<String> = []) {
		self.excludedFields = excludedFields
	}

	public static let none = DataMinimizationOverrides(excludedFields: [])

	public func allows(_ field: String) -> Bool {
		!excludedFields.contains(field)
	}

	/// Canonical field names clients can exclude.
	public enum Field {
		public static let ipAddress = "ip_address"
		public static let cpuCores = "cpu_cores"
		public static let memory = "memory"
		public static let devicePixelRatio = "device_pixel_ratio"
		public static let colorDepth = "color_depth"
		public static let colorGamut = "color_gamut"
		public static let timezone = "timezone"
		public static let language = "language"
		public static let screenDimensions = "screen_dimensions"
		public static let orientation = "orientation"
	}
}

// MARK: - Retention Policy

/// Retention policy for locally persisted touch events and consent receipts.
/// GDPR Art. 5(1)(e) requires data to be kept no longer than necessary; this
/// gives clients a single knob to enforce that on-device.
public struct RetentionPolicy: Codable, Sendable {
	/// How long touch events may sit on disk before auto-purge. Defaults to 7 days.
	public let touchEventTTL: TimeInterval
	/// How long consent receipts are retained. Defaults to 2 years (long enough
	/// to satisfy demonstrable-consent audits in most jurisdictions).
	public let consentReceiptTTL: TimeInterval

	public init(
		touchEventTTL: TimeInterval = 7 * 24 * 60 * 60,
		consentReceiptTTL: TimeInterval = 2 * 365 * 24 * 60 * 60
	) {
		self.touchEventTTL = touchEventTTL
		self.consentReceiptTTL = consentReceiptTTL
	}

	public static let `default` = RetentionPolicy()
}

// MARK: - Compliance Manager

/// Errors surfaced by compliance gating (region restrictions, etc.).
public enum ComplianceError: Error, Sendable {
	/// SDK is running in a restricted region (EU/California) and the configured
	/// `RegionPolicy` disables collection there.
	case regionRestricted
}

/// Central holder for the active tier, consent receipts, region policy,
/// retention policy, and minimization overrides. Thread-safe via an internal
/// lock so the singleton can be read from any actor context.
public final class ComplianceManager: @unchecked Sendable {
	public static let shared = ComplianceManager()

	private let lock = NSLock()
	private var _tier: DataCollectionTier = .tier1Metrics
	private var _regionPolicy: RegionPolicy = .disableInRestrictedRegions
	private var _retentionPolicy: RetentionPolicy = .default
	private var _overrides: DataMinimizationOverrides = .none

	private init() {
		if let raw = UserDefaults.standard.object(forKey: Keys.tier) as? Int,
		   let stored = DataCollectionTier(rawValue: raw) {
			_tier = stored
		}
		if let raw = UserDefaults.standard.string(forKey: Keys.regionPolicy),
		   let stored = RegionPolicy(rawValue: raw) {
			_regionPolicy = stored
		}
		if let data = UserDefaults.standard.data(forKey: Keys.retentionPolicy),
		   let stored = try? JSONDecoder().decode(RetentionPolicy.self, from: data) {
			_retentionPolicy = stored
		}
		if let data = UserDefaults.standard.data(forKey: Keys.overrides),
		   let stored = try? JSONDecoder().decode(DataMinimizationOverrides.self, from: data) {
			_overrides = stored
		}
	}

	public var tier: DataCollectionTier {
		lock.lock(); defer { lock.unlock() }
		return _tier
	}

	public var regionPolicy: RegionPolicy {
		lock.lock(); defer { lock.unlock() }
		return _regionPolicy
	}

	public var retentionPolicy: RetentionPolicy {
		lock.lock(); defer { lock.unlock() }
		return _retentionPolicy
	}

	public var overrides: DataMinimizationOverrides {
		lock.lock(); defer { lock.unlock() }
		return _overrides
	}

	/// Set the active collection tier. Persisted across app launches.
	public func setTier(_ tier: DataCollectionTier) {
		lock.lock(); _tier = tier; lock.unlock()
		UserDefaults.standard.set(tier.rawValue, forKey: Keys.tier)
	}

	public func setRegionPolicy(_ policy: RegionPolicy) {
		lock.lock(); _regionPolicy = policy; lock.unlock()
		UserDefaults.standard.set(policy.rawValue, forKey: Keys.regionPolicy)
	}

	public func setRetentionPolicy(_ policy: RetentionPolicy) {
		lock.lock(); _retentionPolicy = policy; lock.unlock()
		if let data = try? JSONEncoder().encode(policy) {
			UserDefaults.standard.set(data, forKey: Keys.retentionPolicy)
		}
	}

	public func setOverrides(_ overrides: DataMinimizationOverrides) {
		lock.lock(); _overrides = overrides; lock.unlock()
		if let data = try? JSONEncoder().encode(overrides) {
			UserDefaults.standard.set(data, forKey: Keys.overrides)
		}
	}

	/// Applies the configured region policy. Returns the effective tier the
	/// SDK should actually use, or throws `ComplianceError.regionRestricted`
	/// if the policy disables collection entirely.
	public func effectiveTier(requested: DataCollectionTier) throws -> DataCollectionTier {
		guard RegionDetector.isRestrictedRegion() else { return requested }
		switch regionPolicy {
		case .allowAll:
			return requested
		case .clampToTier1InRestrictedRegions:
			return .tier1Metrics
		case .disableInRestrictedRegions:
			throw ComplianceError.regionRestricted
		}
	}

	// MARK: Consent Receipts

	/// Persist a consent receipt. Appends to the local audit log, prunes any
	/// entries older than the configured retention window, and never mutates
	/// existing non-expired entries.
	public func recordConsent(_ receipt: ConsentReceipt) {
		var log = loadConsentLog()
		let cutoff = Date().addingTimeInterval(-retentionPolicy.consentReceiptTTL)
		log = log.filter { $0.timestamp >= cutoff }
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
		static let regionPolicy = "luciaSDK.regionPolicy"
		static let retentionPolicy = "luciaSDK.retentionPolicy"
		static let overrides = "luciaSDK.minimizationOverrides"
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
