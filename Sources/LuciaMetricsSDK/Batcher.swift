//
//  Batcher.swift
//  LuciaMetricsSDK
//
//  Created by Stefan Progovac on 10/1/25.
//

// Sources/TouchEventBatcher/TouchEventBatcher.swift
import Foundation
import Combine
import Network
import UIKit

public protocol BackendService {
	@available(iOS 17, *)
	func sendEvents(_ events: [LuciaTouchEvent]) async throws
}

public final class MockBackendService: BackendService {
	@available(iOS 17, *)
	public func sendEvents(_ events: [LuciaTouchEvent]) async throws {
		for event in events {
			try await Task.sleep(nanoseconds: 1_000_000_000)
			print("[MOCK API SERVICE] sending event: \(event.id)")
		}
	}
}

// Encodable version of the event to match the exact JSON structure expected by the API.
// This ensures the JSON keys match precisely (e.g., "rawX" instead of snake_case).
@available(iOS 17, *)
struct APIEvent: Encodable {
	let type: String
	let lid: String
	let timestamp: Int64
	let rawX: Float
	let rawY: Float
	let pressure: Float
	let size: Float
	let velocityX: Float
	let velocityY: Float
	let user: APIUser?
	let session: APISession

	struct APIUser: Encodable {
		let name: String
	}

	struct APISession: Encodable {
		let id: String
		let hash: String
	}

	init(from event: LuciaTouchEvent, session: APISession, user: APIUser? = nil, lid: String) {
		self.type = event.type
		self.lid = lid
		self.timestamp = Int64(event.timestamp)
		self.rawX = event.rawX
		self.rawY = event.rawY
		self.pressure = event.pressure
		self.size = event.size
		self.velocityX = event.velocityX ?? 0.0
		self.velocityY = event.velocityY ?? 0.0
		self.user = user
		self.session = session
	}
}

// The payload structure matching { "events": [array of events] }
@available(iOS 17, *)
private struct APIPayload: Encodable {
	let events: [APIEvent]
}

// Implementation of the BackendService protocol
@available(iOS 17, *)
final class BackendServiceImpl: BackendService {
	private let baseURL: URL
	private let session: URLSession
	private let appInformation: AppInformation
	private let apiKey: String

	// Initialize with a base URL (e.g., "https://yourapi.com/").
	// You can make this configurable or inject dependencies as needed.
	init(baseURL: URL,
		 session: URLSession = .shared,
		 appInformation: AppInformation,
		 apiKey: String
	) {
		self.baseURL = baseURL
		self.session = session
		self.apiKey = apiKey
		self.appInformation = appInformation
	}

	@available(iOS 17, *)
	public func sendEvents(_ events: [LuciaTouchEvent]) async throws {
		// Map LuciaTouchEvent to APIEvent
		let apiEvents = events.map { APIEvent(from: $0, session: appInformation.luciaSession, user: appInformation.luciaUser, lid: appInformation.lid) }

		// Create payload
		let payload = APIPayload(events: apiEvents)

		// Encode to JSON
		let encoder = JSONEncoder()
		let jsonData = try encoder.encode(payload)

		// Construct the URL for the endpoint
		var urlComponents = URLComponents(url: baseURL.appendingPathComponent("api/sdk/motion/batch"), resolvingAgainstBaseURL: true)
		guard let url = urlComponents?.url else {
			throw URLError(.badURL)
		}

		let userAgent = await UIApplication.generateUserAgent(appName: self.appInformation.appName, appVersion: self.appInformation.appVersion, buildNumber: self.appInformation.appBuild)

		// Create the request
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
		request.setValue("iOS-1.0.0", forHTTPHeaderField: "sdk-version")
		request.setValue("*/*", forHTTPHeaderField: "Accept")
		request.httpBody = jsonData

		// Send the request using URLSession
		let (data, response) = try await session.data(for: request)

		if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
			print("\(json)")
		}


		// Check for successful response (adjust status codes as per your API)
		guard let httpResponse = response as? HTTPURLResponse,
			  (200...299).contains(httpResponse.statusCode) else {
			throw URLError(.badServerResponse)
		}

		// If needed, you can parse the response here, but since the protocol doesn't return anything, we're done.
	}
}

// Example usage:
// let service = BackendServiceImpl(baseURL: URL(string: "https://yourapi.com")!)
// try await service.sendEvents([yourEventsArray])


@available(iOS 17, *)
final public class Batcher: @unchecked Sendable {
	public enum BatcherError: Error {
		case storageError
		case networkError
		case invalidState
	}

	private let backendService: BackendService
	private let maxBatchSize: Int
	private let maxBatchTime: TimeInterval
	private let storage: EventStorage
	private let networkMonitor: NetworkMonitor

	private var currentBatch: [LuciaTouchEvent] = []
	private var batchTimer: Timer?
	private var cancellables = Set<AnyCancellable>()

	public init(
		backendService: BackendService,
		maxBatchSize: Int = 10,
		maxBatchTime: TimeInterval = 10,
		storage: EventStorage = FileEventStorage(),
		networkMonitor: NetworkMonitor = SystemNetworkMonitor()
	) {
		self.backendService = backendService
		self.maxBatchSize = maxBatchSize
		self.maxBatchTime = maxBatchTime
		self.storage = storage
		self.networkMonitor = networkMonitor

		setupObservers()
		loadPendingEvents()
	}

	deinit {
		batchTimer?.invalidate()
	}

	@available(iOS 17, *)
	public func addEvent(_ event: LuciaTouchEvent) {
		currentBatch.append(event)

		// Check if we reached batch size limit
		if currentBatch.count >= maxBatchSize {
			flushBatch()
			return
		}

		// Start timer if this is the first event
		if currentBatch.count == 1 {
			startBatchTimer()
		}

		// Persist event for crash recovery
		Task {
			try? await storage.saveEvent(event)
		}
	}

	public func flush() async throws {
		guard !currentBatch.isEmpty else { return }

		let eventsToSend = currentBatch
		currentBatch.removeAll()
		batchTimer?.invalidate()

		do {
			try await backendService.sendEvents(eventsToSend)
			// Remove sent events from persistent storage
			try await storage.removeEvents(eventsToSend)
		} catch {
			// Re-add events to current batch and restart timer
			currentBatch.append(contentsOf: eventsToSend)
			if !currentBatch.isEmpty {
				startBatchTimer()
			}
			throw error
		}
	}

	private func startBatchTimer() {
		batchTimer?.invalidate()
		batchTimer = Timer.scheduledTimer(withTimeInterval: maxBatchTime, repeats: false) { [weak self] _ in
			self?.flushBatch()
		}
	}

	private func flushBatch() {
		Task {
			try? await flush()
		}
	}

	private func setupObservers() {
		// App background/foreground notifications
		NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
			.sink { [weak self] _ in
				self?.handleAppBackground()
			}
			.store(in: &cancellables)

		NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
			.sink { [weak self] _ in
				self?.handleAppForeground()
			}
			.store(in: &cancellables)

		NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
			.sink { [weak self] _ in
				self?.handleAppTermination()
			}
			.store(in: &cancellables)

		// Network availability
		networkMonitor.networkStatusPublisher
			.sink { [weak self] isAvailable in
				if isAvailable {
					self?.trySendPendingEvents()
				}
			}
			.store(in: &cancellables)
	}

	private func handleAppBackground() {
		flushBatch()
	}

	private func handleAppForeground() {
		trySendPendingEvents()
	}

	private func handleAppTermination() {
		// Synchronous save for termination
		let events = currentBatch
		if !events.isEmpty {
			Task {
				try? await storage.saveEvents(events)
			}
		}
	}

	private func loadPendingEvents() {
		Task {
			do {
				let pendingEvents = try await storage.loadPendingEvents()
				currentBatch.append(contentsOf: pendingEvents)

				if !currentBatch.isEmpty {
					startBatchTimer()
					trySendPendingEvents()
				}
			} catch {
				print("Error loading pending events: \(error)")
			}
		}
	}

	private func trySendPendingEvents() {
		guard networkMonitor.isNetworkAvailable else { return }

		Task {
			try? await flush()

			// Also try to send any other pending events from storage
			let storedEvents = try? await storage.loadPendingEvents()
			if let storedEvents = storedEvents, !storedEvents.isEmpty {
				do {
					try await backendService.sendEvents(storedEvents)
					try await storage.removeEvents(storedEvents)
				} catch {
					print("Failed to send stored events: \(error)")
				}
			}
		}
	}
}
@available(iOS 17, *)
public protocol EventStorage {
	func saveEvent(_ event: LuciaTouchEvent) async throws
	func saveEvents(_ events: [LuciaTouchEvent]) async throws
	func loadPendingEvents() async throws -> [LuciaTouchEvent]
	func removeEvents(_ events: [LuciaTouchEvent]) async throws
}

@available(iOS 17, *)
public class FileEventStorage: EventStorage {
	private let fileManager: FileManager
	private let storageDirectory: URL
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	public init(fileManager: FileManager = .default) {
		self.fileManager = fileManager

		let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
		storageDirectory = documentsDirectory.appendingPathComponent("TouchEvents")

		// Create directory if it doesn't exist
		try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
	}

	public func saveEvent(_ event: LuciaTouchEvent) async throws {
		try await saveEvents([event])
	}

	public func saveEvents(_ events: [LuciaTouchEvent]) async throws {
		for event in events {
			let fileURL = storageDirectory.appendingPathComponent("\(event.id.uuidString).json")
			let data = try encoder.encode(event)
			try data.write(to: fileURL)
		}
	}

	public func loadPendingEvents() async throws -> [LuciaTouchEvent] {
		let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)

		var events: [LuciaTouchEvent] = []
		for fileURL in fileURLs where fileURL.pathExtension == "json" {
			let data = try Data(contentsOf: fileURL)
			let event = try decoder.decode(LuciaTouchEvent.self, from: data)
			events.append(event)
		}

		return events.sorted { $0.timestamp < $1.timestamp }
	}

	public func removeEvents(_ events: [LuciaTouchEvent]) async throws {
		for event in events {
			let fileURL = storageDirectory.appendingPathComponent("\(event.id.uuidString).json")
			try? fileManager.removeItem(at: fileURL)
		}
	}
}

public protocol NetworkMonitor {
	var isNetworkAvailable: Bool { get }
	var networkStatusPublisher: AnyPublisher<Bool, Never> { get }
}

public class SystemNetworkMonitor: NetworkMonitor, @unchecked Sendable {
	private let monitor: NWPathMonitor
	private let subject = PassthroughSubject<Bool, Never>()

	public var isNetworkAvailable: Bool {
		monitor.currentPath.status == .satisfied
	}

	public var networkStatusPublisher: AnyPublisher<Bool, Never> {
		subject.eraseToAnyPublisher()
	}

	public init() {
		monitor = NWPathMonitor()
		monitor.pathUpdateHandler = { [weak self] path in
			self?.subject.send(path.status == .satisfied)
		}
		monitor.start(queue: DispatchQueue.global())
	}

	deinit {
		monitor.cancel()
	}
}

@available(iOS 17, *)
final public class RecordTouchEvents {
	private init() {
		self.appInformation = UserDefaults.standard.loadAppInformation()
	}

	private func createBatcher() -> Batcher? {
		if self.appInformation == nil {
			self.appInformation = UserDefaults.standard.loadAppInformation()
		}

		guard let appInformation = self.appInformation else { return nil }
		guard let apiKey = Bundle.main.infoDictionary?["LuciaSDKKey"] as? String else { return nil }

		let baseURL: URL = URL(string: "https://hypsometrical-catabolically-teresita.ngrok-free.dev/")! // hardcoded for now

		let service = BackendServiceImpl(baseURL: baseURL, appInformation: appInformation, apiKey: apiKey)


		return Batcher(backendService: service)
	}

	private var batcher: Batcher?
	private var appInformation: AppInformation?

	nonisolated(unsafe) public static let shared = RecordTouchEvents()

	public func record(_ event: LuciaTouchEvent) {
		if self.batcher == nil {
			self.batcher = createBatcher()
		}
		batcher?.addEvent(event)
	}

}






