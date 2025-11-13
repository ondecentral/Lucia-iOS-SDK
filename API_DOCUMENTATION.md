# Lucia Metrics SDK - API Documentation

Comprehensive API reference for the Lucia Metrics SDK for iOS.

## Table of Contents

- [MetricsCollector](#metricscollector)
- [MetricsEnvironment](#metricsenvironment)
- [MetricsError](#metricserror)
- [DeviceMetrics](#devicemetrics)
- [Touch Events (iOS 17+)](#touch-events-ios-17)
- [Event Batching](#event-batching)

---

## MetricsCollector

The main class for collecting device metrics and initializing the SDK.

### Properties

#### `shared`
```swift
public static let shared: MetricsCollector
```
Singleton instance for accessing the metrics collector.

### Methods

#### `captureDeviceFingerprint`
```swift
@MainActor
public func captureDeviceFingerprint(
    versionNumber: String,
    buildNumber: String,
    appName: String,
    userName: String? = nil,
    environment: MetricsEnvironment = .staging,
    completion: @escaping @Sendable (Result<String, MetricsError>) -> Void
) async
```

Captures device fingerprint and initializes the SDK with the Lucia backend.

**Parameters:**
- `versionNumber`: Your app's version number (e.g., "1.0.0")
- `buildNumber`: Your app's build number (e.g., "100")
- `appName`: Name of your application
- `userName`: Optional username or email for user-specific tracking
- `environment`: Environment to connect to (default: `.staging`)
- `completion`: Callback with Result containing the Lucia ID (LID) or error

**Returns:** The Lucia ID (LID) as a String on success

**Example:**
```swift
await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "100",
    appName: "MyApp",
    userName: "user@example.com",
    environment: .staging
) { result in
    switch result {
    case .success(let lid):
        print("Initialized with LID: \(lid)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

#### `collectMetrics`
```swift
@MainActor
public func collectMetrics() throws -> DeviceMetrics
```

Collects all available device metrics.

**Returns:** Dictionary containing device metrics

**Throws:** 
- `MetricsError.permissionDenied` if IDFA permission is denied
- `MetricsError.networkUnavailable` if IP address cannot be determined
- `MetricsError.unknown` for other errors

**Example:**
```swift
do {
    let metrics = try await MetricsCollector.shared.collectMetrics()
    print("Device ID: \(metrics["device_id"] ?? "unknown")")
    print("IDFV: \(metrics["idfv"] ?? "unknown")")
} catch {
    print("Failed to collect metrics: \(error)")
}
```

#### `requestTrackingPermission`
```swift
func requestTrackingPermission(
    completion: @escaping @Sendable (Bool) -> Void
)
```

Requests App Tracking Transparency (ATT) permission for IDFA access.

**Parameters:**
- `completion`: Callback with boolean indicating if permission was granted

**Example:**
```swift
MetricsCollector.shared.requestTrackingPermission { granted in
    if granted {
        print("Tracking permission granted")
    } else {
        print("Tracking permission denied")
    }
}
```

---

## MetricsEnvironment

Enum defining available environments for the SDK.

### Cases

#### `.develop(url:)`
```swift
case develop(url: String)
```
Custom development environment with a specified URL.

**Example:**
```swift
let env = MetricsEnvironment.develop(url: "https://localhost:3000")
```

#### `.test`
```swift
case test
```
Internal testing environment.

#### `.staging`
```swift
case staging
```
Staging environment for pre-production testing (default).

#### `.prod`
```swift
case prod
```
Production environment for live applications.

### Properties

#### `config`
```swift
var config: MetricsConfig { get }
```
Returns the configuration (base URL and API key) for the environment.

---

## MetricsError

Error types that can occur during SDK operations.

### Cases

#### `.permissionDenied`
```swift
case permissionDenied
```
User denied tracking permission or IDFA is not available.

#### `.networkUnavailable`
```swift
case networkUnavailable
```
Network connection is unavailable or IP address cannot be determined.

#### `.syncFailed(error:)`
```swift
case syncFailed(error: Error)
```
Failed to synchronize data with the backend.

**Associated Value:** The underlying error that caused the sync failure

#### `.unknown`
```swift
case unknown
```
An unknown error occurred.

---

## DeviceMetrics

Type alias for device metrics dictionary.

```swift
public typealias DeviceMetrics = [String: String]
```

### Keys

Use `MetricKeys` enum for accessing metrics:

```swift
public enum MetricKeys: String {
    case deviceId = "device_id"      // IDFA
    case idfv = "idfv"               // Identifier for Vendor
    case ipAddress = "ip_address"    // IP address
    case deviceModel = "device_model" // Device model
    case osVersion = "os_version"    // iOS version
}
```

### Extension: fingerprint

```swift
public extension DeviceMetrics {
    var fingerprint: String { get }
}
```

Generates a unique fingerprint by combining IDFV and device ID.

**Example:**
```swift
let metrics = try await MetricsCollector.shared.collectMetrics()
let fingerprint = metrics.fingerprint
print("Device fingerprint: \(fingerprint)")
```

---

## Touch Events (iOS 17+)

Touch event tracking is available on iOS 17 and later.

### UIApplication Extension

#### `recordTouches()`
```swift
@available(iOS 17, *)
public func recordTouches()
```

Enables touch event recording for the application.

**Example:**
```swift
if #available(iOS 17, *) {
    UIApplication.shared.recordTouches()
}
```

### LuciaTouchEvent

Model representing a touch event.

#### Properties

```swift
public var id: UUID
public var sessionID: String?
public var timestamp: Double
public var type: String
public var rawX: Float
public var rawY: Float
public var pressure: Float
public var size: Float
public var velocityX: Float?
public var velocityY: Float?
public var distanceX: Float?
public var distanceY: Float?
```

#### Factory Methods

##### `create(touch:in:)`
```swift
@MainActor
public static func create(
    touch: UITouch,
    in view: UIView?
) -> LuciaTouchEvent
```

Creates a basic touch event.

##### `createFling(touch:in:velocity:)`
```swift
@MainActor
public static func createFling(
    touch: UITouch,
    in view: UIView?,
    velocity: CGPoint?
) -> LuciaTouchEvent
```

Creates a fling/swipe event with velocity information.

##### `createScroll(touch:in:distance:)`
```swift
@MainActor
public static func createScroll(
    touch: UITouch,
    in view: UIView?,
    distance: CGPoint?
) -> LuciaTouchEvent
```

Creates a scroll/drag event with distance information.

---

## Event Batching

The SDK automatically batches touch events for efficient network usage.

### Batcher

Main class responsible for batching and syncing events.

#### Initialization

```swift
@available(iOS 17, *)
public init(
    backendService: BackendService,
    maxBatchSize: Int = 10,
    maxBatchTime: TimeInterval = 10,
    storage: EventStorage = FileEventStorage(),
    networkMonitor: NetworkMonitor = SystemNetworkMonitor()
)
```

**Parameters:**
- `backendService`: Service for sending events to backend
- `maxBatchSize`: Maximum number of events per batch (default: 10)
- `maxBatchTime`: Maximum seconds between batches (default: 10)
- `storage`: Storage implementation for persistence
- `networkMonitor`: Network monitoring implementation

#### Methods

##### `addEvent(_:)`
```swift
@available(iOS 17, *)
public func addEvent(_ event: LuciaTouchEvent)
```

Adds an event to the current batch.

##### `flush()`
```swift
public func flush() async throws
```

Manually flushes the current batch to the backend.

### RecordTouchEvents

Singleton for recording touch events.

#### Properties

```swift
@available(iOS 17, *)
public static let shared: RecordTouchEvents
```

#### Methods

##### `record(_:)`
```swift
public func record(_ event: LuciaTouchEvent)
```

Records a touch event and adds it to the batch.

**Example:**
```swift
if #available(iOS 17, *) {
    let touchEvent = LuciaTouchEvent.create(touch: touch, in: view)
    RecordTouchEvents.shared.record(touchEvent)
}
```

### Batching Behavior

- **Automatic Flushing**: Batch is flushed when:
  - Batch size reaches `maxBatchSize` (default: 10 events)
  - Time since first event exceeds `maxBatchTime` (default: 10 seconds)
  - App enters background
  - App terminates

- **Offline Support**: 
  - Events are persisted to disk
  - Automatically synced when network becomes available
  - Retries failed requests

- **Network-Aware**:
  - Monitors network status
  - Pauses syncing when offline
  - Resumes when connection restored

---

## Data Models

### AppInformation

Internal model storing app and session information.

```swift
struct AppInformation: Codable {
    let lid: String
    let userName: String?
    let appName: String
    let appVersion: String
    let appBuild: String
    let sessionId: String
    let sessionHash: String
}
```

### MetricsPayload

Internal model for the metrics payload sent to the backend.

```swift
struct MetricsPayload: Codable {
    let data: DataObject
    let redirectHash: String?
    let session: Session
    let user: User
    let walletData: WalletData
    let utm: UTM
}
```

---

## UserDefaults Extensions

The SDK extends UserDefaults for persisting app information.

### Methods

#### `saveAppInformation(_:)`
```swift
func saveAppInformation(_ info: AppInformation) -> Bool
```

Saves app information to UserDefaults.

#### `loadAppInformation()`
```swift
func loadAppInformation() -> AppInformation?
```

Loads saved app information from UserDefaults.

---

## Thread Safety

### Actors and Sendable

- Most SDK operations must be called from the `@MainActor`
- Completion handlers are marked `@Sendable` for thread safety
- Internal models conform to `Sendable` where appropriate

### Example
```swift
Task { @MainActor in
    await MetricsCollector.shared.captureDeviceFingerprint(
        versionNumber: "1.0.0",
        buildNumber: "1",
        appName: "MyApp"
    ) { result in
        // This completion handler can be called from any thread
        DispatchQueue.main.async {
            // Update UI safely
        }
    }
}
```

---

## Privacy & Security

### Data Collection

The SDK collects:
- **IDFA**: With user permission (ATT framework)
- **IDFV**: Automatically available
- **IP Address**: Current device IP
- **Device Info**: Model, OS version
- **Touch Events**: Coordinates, pressure, velocity (iOS 17+)

### Privacy Compliance

- Respects user tracking preferences
- Falls back to IDFV when IDFA unavailable
- Transparent data collection logging
- Complies with App Store guidelines

### Security

- API keys stored in Info.plist (not hardcoded)
- HTTPS-only communication
- No sensitive data in plain text
- Local event storage encrypted by iOS

---

## Best Practices

1. **Initialize Early**: Call in `application(_:didFinishLaunchingWithOptions:)`
2. **Handle Errors**: Always check completion Result
3. **Use Staging**: Test with `.staging` before production
4. **Respect Privacy**: Only enable with user consent
5. **Monitor Logs**: Watch for SDK log messages during development

---

## Version History

### 1.0.0 (Current)
- Initial release
- Device fingerprinting
- Touch event tracking (iOS 17+)
- Event batching
- Multi-environment support

---

## Support

- 📧 Email: support@clickinsights.xyz
- 🐛 Issues: [GitHub](https://github.com/your-org/Lucia-iOS-SDK/issues)
- 📚 Docs: [Documentation](https://docs.clickinsights.xyz)
