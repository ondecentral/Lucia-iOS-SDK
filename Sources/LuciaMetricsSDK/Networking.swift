//
//  Networking.swift
//  LuciaMetricsSDK
//
//  TLS certificate pinning and shared URLSession factory.
//
//  Pinning addresses the MEDIUM-priority MITM mitigation called out in the
//  April 2026 compliance audit. Pins are validated against the leaf
//  certificate's Subject Public Key Info (SPKI) SHA-256 — the same approach
//  recommended by OWASP Mobile and what the major SDKs (Stripe, Datadog) use.
//
//  Pins are configured by the host application via Info.plist:
//    <key>LuciaSDKPinnedCertHashes</key>
//    <array>
//      <string>sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</string>
//    </array>
//
//  If no pins are declared the delegate falls back to the system default trust
//  evaluation. This keeps existing client integrations working while letting
//  security-conscious clients harden their builds.
//

import Foundation
import CryptoKit

/// Configuration for certificate pinning. Reads pin hashes from the host app's
/// Info.plist and exposes a normalized accessor used by the URLSession delegate.
public enum CertificatePinning {
	/// Info.plist key for the pinned-hash array. Each entry is a base64 SHA-256
	/// of the certificate's Subject Public Key Info, prefixed with "sha256/".
	public static let infoPlistKey = "LuciaSDKPinnedCertHashes"

	/// Returns the configured pin set, or an empty set if pinning is not enabled
	/// for this host app.
	public static func configuredPins(bundle: Bundle = .main) -> Set<String> {
		guard let raw = bundle.infoDictionary?[infoPlistKey] as? [String] else {
			return []
		}
		return Set(raw.map(normalizePin))
	}

	/// Strips the optional "sha256/" prefix and trims whitespace so the host
	/// app's plist format is forgiving.
	static func normalizePin(_ pin: String) -> String {
		var trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.lowercased().hasPrefix("sha256/") {
			trimmed = String(trimmed.dropFirst("sha256/".count))
		}
		return trimmed
	}
}

/// URLSession delegate that enforces SPKI pinning for backend hosts. Used by
/// both `MetricsSyncer` and `BackendServiceImpl`.
final class CertificatePinningSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

	/// Hosts to which pinning applies. Requests to other hosts (which the SDK
	/// shouldn't be making, but defense in depth) are subject to default trust
	/// evaluation only.
	static let pinnedHosts: Set<String> = [
		"api.luciaprotocol.com",
		"staging.api.luciaprotocol.com"
	]

	private let pins: Set<String>

	init(pins: Set<String> = CertificatePinning.configuredPins()) {
		self.pins = pins
	}

	func urlSession(
		_ session: URLSession,
		didReceive challenge: URLAuthenticationChallenge,
		completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
	) {
		guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
			  let serverTrust = challenge.protectionSpace.serverTrust else {
			completionHandler(.performDefaultHandling, nil)
			return
		}

		let host = challenge.protectionSpace.host

		// If pinning is not configured for this build, fall back to system trust.
		// This keeps the SDK functional for clients who haven't yet rolled pins
		// into their Info.plist.
		if pins.isEmpty {
			completionHandler(.performDefaultHandling, nil)
			return
		}

		// Only enforce pinning for the hosts we actually own. Anything else
		// (rare, but e.g. a redirect) gets default handling.
		guard Self.pinnedHosts.contains(host) else {
			completionHandler(.performDefaultHandling, nil)
			return
		}

		// First, run the system's standard chain validation. Pinning is an
		// addition to PKI, not a replacement.
		var error: CFError?
		let trusted = SecTrustEvaluateWithError(serverTrust, &error)
		guard trusted else {
			completionHandler(.cancelAuthenticationChallenge, nil)
			return
		}

		// Then validate the leaf cert's SPKI hash against the configured pins.
		guard let leaf = leafCertificate(of: serverTrust),
			  let leafPin = spkiPin(for: leaf),
			  pins.contains(leafPin) else {
			completionHandler(.cancelAuthenticationChallenge, nil)
			return
		}

		completionHandler(.useCredential, URLCredential(trust: serverTrust))
	}

	// MARK: - Internals

	private func leafCertificate(of trust: SecTrust) -> SecCertificate? {
		if #available(iOS 15.0, *) {
			return (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
		} else {
			guard SecTrustGetCertificateCount(trust) > 0 else { return nil }
			return SecTrustGetCertificateAtIndex(trust, 0)
		}
	}

	/// Extracts the Subject Public Key Info (SPKI), DER-encodes it, and returns
	/// the base64 SHA-256 — the standard "SPKI pin" format.
	private func spkiPin(for certificate: SecCertificate) -> String? {
		guard let publicKey = SecCertificateCopyKey(certificate),
			  let spki = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
			return nil
		}
		let digest = SHA256.hash(data: spki)
		return Data(digest).base64EncodedString()
	}
}

/// Factory for the SDK's pinned URLSession. All SDK network traffic should go
/// through this to inherit pinning.
enum LuciaURLSessionFactory {
	/// Cached delegate so we only build one per process. URLSession retains its
	/// delegate strongly, so this matches the typical Apple sample code.
	private static let delegate = CertificatePinningSessionDelegate()

	/// Returns a URLSession that enforces SPKI pinning when configured. If the
	/// host app hasn't declared `LuciaSDKPinnedCertHashes`, this still returns a
	/// session with the delegate attached so the security posture is consistent
	/// — it just falls back to default trust evaluation.
	static func makeSession(configuration: URLSessionConfiguration = .default) -> URLSession {
		URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
	}
}
