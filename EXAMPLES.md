# Examples

This document provides practical examples for common use cases with the Lucia Metrics SDK.

## Table of Contents

1. [Basic Setup Examples](#basic-setup-examples)
2. [Environment Configuration](#environment-configuration)
3. [Error Handling](#error-handling)
4. [User Tracking](#user-tracking)
5. [Touch Event Examples](#touch-event-examples)
6. [Advanced Usage](#advanced-usage)

---

## Basic Setup Examples

### UIKit - AppDelegate

```swift
import UIKit
import LuciaMetricsSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        setupLuciaSDK()
        return true
    }
    
    private func setupLuciaSDK() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
                appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App",
                environment: .staging
            ) { result in
                self.handleLuciaInitialization(result)
            }
        }
    }
    
    private func handleLuciaInitialization(_ result: Result<String, MetricsError>) {
        switch result {
        case .success(let lid):
            print("✅ Lucia SDK initialized")
            print("   LID: \(lid)")
            // Optionally enable touch tracking
            self.enableTouchTracking()
            
        case .failure(let error):
            print("❌ Lucia SDK initialization failed: \(error)")
        }
    }
    
    @available(iOS 17, *)
    private func enableTouchTracking() {
        UIApplication.shared.recordTouches()
        print("✅ Touch tracking enabled")
    }
}
```

### SwiftUI - App Entry Point

```swift
import SwiftUI
import LuciaMetricsSDK

@main
struct MyApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        setupLuciaSDK()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
    
    private func setupLuciaSDK() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "100",
                appName: "MyApp",
                environment: .staging
            ) { [weak appState] result in
                guard let appState = appState else { return }
                
                switch result {
                case .success(let lid):
                    appState.luciaDeviceId = lid
                    appState.isLuciaInitialized = true
                    
                case .failure(let error):
                    appState.luciaError = error
                }
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isLuciaInitialized = false
    @Published var luciaDeviceId: String?
    @Published var luciaError: MetricsError?
}
```

---

## Environment Configuration

### Development Environment

```swift
// For local development
let devEnvironment = MetricsEnvironment.develop(url: "http://localhost:3000")

await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "1",
    appName: "MyApp",
    environment: devEnvironment
) { result in
    // Handle result
}
```

### Environment Based on Build Configuration

```swift
private var luciaEnvironment: MetricsEnvironment {
    #if DEBUG
    return .test
    #elseif STAGING
    return .staging
    #else
    return .prod
    #endif
}

Task { @MainActor in
    await MetricsCollector.shared.captureDeviceFingerprint(
        versionNumber: "1.0.0",
        buildNumber: "1",
        appName: "MyApp",
        environment: luciaEnvironment
    ) { result in
        // Handle result
    }
}
```

### Dynamic Environment Selection

```swift
enum AppConfiguration {
    case development
    case staging
    case production
    
    var luciaEnvironment: MetricsEnvironment {
        switch self {
        case .development:
            return .develop(url: "https://dev.api.mycompany.com")
        case .staging:
            return .staging
        case .production:
            return .prod
        }
    }
}

let config = AppConfiguration.staging
let environment = config.luciaEnvironment
```

---

## Error Handling

### Comprehensive Error Handling

```swift
await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "1",
    appName: "MyApp"
) { result in
    switch result {
    case .success(let lid):
        // Success - save LID for later use
        UserDefaults.standard.set(lid, forKey: "lucia_device_id")
        print("Device tracking initialized: \(lid)")
        
    case .failure(.permissionDenied):
        // User denied tracking permission
        print("Tracking permission denied")
        // Show in-app message explaining benefits
        self.showTrackingBenefitsModal()
        
    case .failure(.networkUnavailable):
        // No network connection
        print("Network unavailable - will retry")
        // The SDK will automatically retry when network is available
        self.showNoNetworkBanner()
        
    case .failure(.syncFailed(let error)):
        // Failed to sync with backend
        print("Sync failed: \(error.localizedDescription)")
        // Log to analytics or crash reporting
        Analytics.logError("lucia_sync_failed", error: error)
        
    case .failure(.unknown):
        // Unknown error
        print("Unknown error occurred")
        // Log for debugging
        Analytics.logError("lucia_unknown_error")
    }
}
```

### Retry Logic

```swift
func initializeLuciaWithRetry(maxRetries: Int = 3, delay: TimeInterval = 2.0) {
    var retryCount = 0
    
    func attempt() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "1",
                appName: "MyApp"
            ) { result in
                switch result {
                case .success(let lid):
                    print("✅ Initialized after \(retryCount) retries")
                    
                case .failure(let error):
                    retryCount += 1
                    if retryCount < maxRetries {
                        print("⚠️ Retry \(retryCount)/\(maxRetries)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        print("❌ Failed after \(maxRetries) retries: \(error)")
                    }
                }
            }
        }
    }
    
    attempt()
}
```

---

## User Tracking

### Anonymous User Tracking

```swift
// Initialize without username
await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "1",
    appName: "MyApp",
    userName: nil  // Anonymous tracking
) { result in
    // Handle result
}
```

### Authenticated User Tracking

```swift
// After user logs in
func setupUserTracking(for user: User) {
    Task { @MainActor in
        await MetricsCollector.shared.captureDeviceFingerprint(
            versionNumber: "1.0.0",
            buildNumber: "1",
            appName: "MyApp",
            userName: user.email  // Track with email
        ) { result in
            if case .success(let lid) = result {
                // Associate LID with user profile
                updateUserProfile(lid: lid, user: user)
            }
        }
    }
}
```

### Update User Context After Login

```swift
class UserSession {
    func login(email: String, password: String) async throws {
        // Perform login
        let user = try await authService.login(email: email, password: password)
        
        // Re-initialize Lucia with user context
        await MetricsCollector.shared.captureDeviceFingerprint(
            versionNumber: "1.0.0",
            buildNumber: "1",
            appName: "MyApp",
            userName: user.email
        ) { result in
            if case .success = result {
                print("User context updated in Lucia")
            }
        }
    }
}
```

---

## Touch Event Examples

### Enable Touch Tracking (iOS 17+)

```swift
@available(iOS 17, *)
func enableTouchTracking() {
    // Must be called after SDK initialization
    UIApplication.shared.recordTouches()
    print("Touch tracking enabled")
}
```

### Custom Touch Event Recording

```swift
@available(iOS 17, *)
class CustomView: UIView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        
        // Create and record touch event
        let touchEvent = LuciaTouchEvent.create(touch: touch, in: self)
        RecordTouchEvents.shared.record(touchEvent)
        
        print("Touch recorded at (\(touchEvent.rawX), \(touchEvent.rawY))")
    }
}
```

### Track Specific Gestures

```swift
@available(iOS 17, *)
class InteractiveView: UIView {
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        panGestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )
        addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let touch = gesture.view?.touches(for: gesture)?.first else { return }
        
        let velocity = gesture.velocity(in: self)
        
        // Create fling event with velocity
        let flingEvent = LuciaTouchEvent.createFling(
            touch: touch,
            in: self,
            velocity: velocity
        )
        RecordTouchEvents.shared.record(flingEvent)
    }
}
```

---

## Advanced Usage

### Async/Await Pattern (iOS 15+)

```swift
@available(iOS 15.0, *)
func initializeSDKAsync() async {
    do {
        let syncer = MetricsSyncer(
            versionNumber: "1.0.0",
            buildNumber: "1",
            appName: "MyApp",
            fingerprint: "device-fingerprint",
            environment: .staging
        )
        
        let lid = try await syncer.initializeSDK()
        print("Initialized with LID: \(lid)")
        
        // Continue with app initialization
        await loadUserData(lid: lid)
        
    } catch {
        print("Failed to initialize: \(error)")
        // Handle error
    }
}
```

### Custom Backend Service

```swift
@available(iOS 17, *)
class CustomBackendService: BackendService {
    func sendEvents(_ events: [LuciaTouchEvent]) async throws {
        // Custom implementation for sending events
        let payload = events.map { event in
            [
                "id": event.id.uuidString,
                "x": event.rawX,
                "y": event.rawY,
                "timestamp": event.timestamp
            ]
        }
        
        // Send to custom endpoint
        try await customAPIClient.send(payload)
    }
}

// Use custom service
let customService = CustomBackendService()
let batcher = Batcher(backendService: customService)
```

### Monitoring SDK Status

```swift
class LuciaSDKManager: ObservableObject {
    @Published var isInitialized = false
    @Published var deviceId: String?
    @Published var lastError: MetricsError?
    @Published var touchTrackingEnabled = false
    
    func initialize() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "1",
                appName: "MyApp"
            ) { [weak self] result in
                switch result {
                case .success(let lid):
                    self?.isInitialized = true
                    self?.deviceId = lid
                    self?.enableTouchTracking()
                    
                case .failure(let error):
                    self?.lastError = error
                    self?.isInitialized = false
                }
            }
        }
    }
    
    @available(iOS 17, *)
    private func enableTouchTracking() {
        UIApplication.shared.recordTouches()
        touchTrackingEnabled = true
    }
}

// Use in SwiftUI
struct SettingsView: View {
    @ObservedObject var sdkManager: LuciaSDKManager
    
    var body: some View {
        Form {
            Section("Lucia SDK Status") {
                HStack {
                    Text("Initialized")
                    Spacer()
                    Image(systemName: sdkManager.isInitialized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(sdkManager.isInitialized ? .green : .red)
                }
                
                if let deviceId = sdkManager.deviceId {
                    Text("Device ID: \(deviceId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Touch Tracking")
                    Spacer()
                    Image(systemName: sdkManager.touchTrackingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(sdkManager.touchTrackingEnabled ? .green : .gray)
                }
            }
        }
    }
}
```

### Integration with Analytics

```swift
class AnalyticsManager {
    static let shared = AnalyticsManager()
    private var luciaDeviceId: String?
    
    func initializeLucia() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "1",
                appName: "MyApp"
            ) { [weak self] result in
                if case .success(let lid) = result {
                    self?.luciaDeviceId = lid
                    
                    // Set as user property in other analytics tools
                    Firebase.Analytics.setUserProperty(lid, forName: "lucia_device_id")
                    Mixpanel.mainInstance().identify(distinctId: lid)
                }
            }
        }
    }
    
    func trackEvent(_ name: String, properties: [String: Any] = [:]) {
        var enrichedProperties = properties
        
        // Add Lucia device ID to all events
        if let lid = luciaDeviceId {
            enrichedProperties["lucia_device_id"] = lid
        }
        
        // Track in your analytics service
        Firebase.Analytics.logEvent(name, parameters: enrichedProperties)
        Mixpanel.mainInstance().track(event: name, properties: enrichedProperties)
    }
}
```

---

## Testing

### Unit Test Example

```swift
import XCTest
@testable import LuciaMetricsSDK

class LuciaSDKTests: XCTestCase {
    
    func testDeviceMetricsCollection() async throws {
        let metrics = try await MetricsCollector.shared.collectMetrics()
        
        XCTAssertNotNil(metrics[MetricKeys.idfv.rawValue])
        XCTAssertNotNil(metrics[MetricKeys.deviceModel.rawValue])
        XCTAssertNotNil(metrics[MetricKeys.osVersion.rawValue])
    }
    
    func testFingerprint() throws {
        let metrics: DeviceMetrics = [
            "device_id": "test-device-id",
            "idfv": "test-idfv"
        ]
        
        let fingerprint = metrics.fingerprint
        XCTAssertEqual(fingerprint, "test-idfv-test-device-id")
    }
}
```

---

## More Examples

For more examples and use cases, check out:
- [Quick Start Guide](QUICKSTART.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Sample App](https://github.com/your-org/Lucia-iOS-SDK-Sample)
