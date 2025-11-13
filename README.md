# Lucia Metrics SDK for iOS

[![Swift Version](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014%2B-blue.svg)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Lucia Metrics SDK is a powerful iOS analytics and user behavior tracking SDK that provides device fingerprinting, touch event tracking, and session management capabilities.

## Features

- 📱 **Device Fingerprinting**: Unique device identification using IDFA, IDFV, and device metrics
- 👆 **Touch Event Tracking**: Capture and analyze user touch interactions (iOS 17+)
- 🔄 **Event Batching**: Efficient event batching with automatic retry and offline support
- 🌐 **Network-Aware**: Automatically syncs events when network is available
- 💾 **Persistent Storage**: Events are saved locally and synced when possible
- 🔐 **Privacy-Focused**: Respects user tracking permissions (ATT framework)

## Requirements

- iOS 14.0+
- Xcode 14.0+
- Swift 6.1+

## Installation

### Swift Package Manager

Add the Lucia Metrics SDK to your project using Swift Package Manager:

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/your-org/Lucia-iOS-SDK.git`
3. Select the version or branch you want to use
4. Click **Add Package**

Alternatively, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/Lucia-iOS-SDK.git", from: "1.0.0")
]
```

## Configuration

### 1. Add API Key to Info.plist

Add your Lucia SDK API key to your app's `Info.plist`:

```xml
<key>LuciaSDKKey</key>
<string>YOUR_API_KEY_HERE</string>
```

Or in Xcode:
1. Open your project's `Info.plist`
2. Add a new row with key `LuciaSDKKey` (String type)
3. Set the value to your API key

### 2. Add Privacy Permissions

Add tracking permission descriptions to your `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use this to provide personalized analytics and improve your experience.</string>
```

## Usage

### Basic Setup

Import the SDK in your code:

```swift
import LuciaMetricsSDK
```

### Initialize the SDK

Initialize the SDK early in your app lifecycle (e.g., in `AppDelegate` or `SceneDelegate`):

```swift
import UIKit
import LuciaMetricsSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Initialize Lucia SDK
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "100",
                appName: "MyApp",
                userName: "user@example.com", // Optional
                environment: .staging
            ) { result in
                switch result {
                case .success(let lid):
                    print("✅ Lucia SDK initialized successfully")
                    print("   Device ID (LID): \(lid)")
                    
                case .failure(let error):
                    print("❌ Failed to initialize Lucia SDK: \(error)")
                }
            }
        }
        
        return true
    }
}
```

### Environment Options

Choose the appropriate environment for your use case:

```swift
// Staging (default) - for testing
environment: .staging

// Production - for live apps
environment: .prod

// Test - internal testing environment
environment: .test

// Development - custom URL for local development
environment: .develop(url: "https://your-local-server.com")
```

### SwiftUI Setup

For SwiftUI apps, initialize in your `App` struct:

```swift
import SwiftUI
import LuciaMetricsSDK

@main
struct MyApp: App {
    
    init() {
        initializeLuciaSDK()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func initializeLuciaSDK() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                appName: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "App",
                userName: nil,
                environment: .staging
            ) { result in
                if case .success(let lid) = result {
                    print("Lucia SDK initialized with LID: \(lid)")
                }
            }
        }
    }
}
```

### Touch Event Tracking (iOS 17+)

Enable touch event tracking to capture user interactions:

```swift
import UIKit
import LuciaMetricsSDK

@available(iOS 17, *)
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Initialize SDK first
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "100",
                appName: "MyApp",
                environment: .staging
            ) { result in
                if case .success = result {
                    // Enable touch event recording after successful initialization
                    UIApplication.shared.recordTouches()
                    print("✅ Touch event tracking enabled")
                }
            }
        }
        
        return true
    }
}
```

### Advanced: Custom Environment

For enterprise or custom deployments:

```swift
let customEnvironment = MetricsEnvironment.develop(url: "https://your-custom-api.com")

await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "100",
    appName: "MyApp",
    environment: customEnvironment
) { result in
    // Handle result
}
```

### Async/Await Support (iOS 15+)

The SDK supports modern async/await syntax:

```swift
@available(iOS 15.0, *)
func initializeSDK() async {
    do {
        let syncer = MetricsSyncer(
            versionNumber: "1.0.0",
            buildNumber: "100",
            appName: "MyApp",
            fingerprint: "device-fingerprint",
            environment: .staging
        )
        
        let lid = try await syncer.initializeSDK()
        print("Initialized with LID: \(lid)")
    } catch {
        print("Failed to initialize: \(error)")
    }
}
```

## Data Collection

### What Data is Collected?

The SDK collects the following device metrics:

- **Device ID (IDFA)**: Requires user permission via ATT framework
- **IDFV**: Identifier for Vendor (automatically available)
- **IP Address**: Current device IP address
- **Device Model**: e.g., "iPhone", "iPad"
- **OS Version**: iOS version number
- **Touch Events** (iOS 17+ only):
  - Touch coordinates (x, y)
  - Pressure and size
  - Touch type (tap, drag, fling)
  - Velocity and distance

### Privacy & Permissions

The SDK respects user privacy:

1. **ATT Compliance**: Requests tracking permission before collecting IDFA
2. **Graceful Degradation**: Falls back to IDFV if IDFA is not available
3. **Transparent**: All data collection is logged for debugging
4. **Opt-out Support**: Tracking can be disabled by the user

## Event Batching

The SDK automatically batches touch events for efficient network usage:

- **Batch Size**: Up to 10 events per batch (configurable)
- **Batch Time**: Maximum 10 seconds between batches (configurable)
- **Offline Support**: Events are saved locally and synced when online
- **App Lifecycle**: Automatically flushes events on app background/termination

## Error Handling

The SDK provides comprehensive error handling:

```swift
public enum MetricsError: Error {
    case permissionDenied      // User denied tracking permission
    case networkUnavailable    // No network connection
    case syncFailed(error: Error)  // Failed to sync with backend
    case unknown               // Unknown error occurred
}
```

Handle errors appropriately in your completion handler:

```swift
await MetricsCollector.shared.captureDeviceFingerprint(
    versionNumber: "1.0.0",
    buildNumber: "100",
    appName: "MyApp"
) { result in
    switch result {
    case .success(let lid):
        print("Success: \(lid)")
        
    case .failure(.permissionDenied):
        print("User denied tracking permission")
        // Show appropriate UI or continue without tracking
        
    case .failure(.networkUnavailable):
        print("No network available")
        // Will retry automatically when network is available
        
    case .failure(.syncFailed(let error)):
        print("Sync failed: \(error)")
        // Handle sync error
        
    case .failure(.unknown):
        print("Unknown error occurred")
    }
}
```

## Testing

### Unit Tests

Run the included unit tests:

```bash
swift test
```

### Manual Testing

Use the `.test` environment for manual testing:

```swift
environment: .test
```

This connects to the test backend without affecting production data.

## Troubleshooting

### API Key Not Found

**Error**: `LuciaSDKKey not found in Info.plist`

**Solution**: Ensure you've added the `LuciaSDKKey` string value to your `Info.plist`

### Permission Denied

**Error**: `MetricsError.permissionDenied`

**Solution**: 
1. Check that you've added `NSUserTrackingUsageDescription` to `Info.plist`
2. Ensure user granted tracking permission
3. The SDK will fall back to IDFV if IDFA is not available

### Network Errors

**Error**: `MetricsError.networkUnavailable` or `MetricsError.syncFailed`

**Solution**:
- The SDK automatically retries when network becomes available
- Check your network connection
- Verify the API endpoint is reachable
- For custom environments, ensure the URL is correct

### Touch Events Not Recording

**Issue**: Touch events are not being captured

**Solution**:
1. Ensure you're on iOS 17+ (touch tracking requires iOS 17+)
2. Verify `UIApplication.shared.recordTouches()` is called after SDK initialization
3. Check console for `[TOUCH]` and `[RECORD]` log messages

## Best Practices

1. **Initialize Early**: Initialize the SDK in `application(_:didFinishLaunchingWithOptions:)` or `App.init()`
2. **Use Staging First**: Test with `.staging` environment before going to production
3. **Handle Errors**: Always handle completion result appropriately
4. **Respect Privacy**: Only enable tracking with user consent
5. **Monitor Logs**: Watch for `[LuciaSDK]` prefixed logs during development

## API Reference

### MetricsCollector

```swift
public class MetricsCollector {
    /// Shared singleton instance
    public static let shared: MetricsCollector
    
    /// Captures device fingerprint and initializes the SDK
    @MainActor
    public func captureDeviceFingerprint(
        versionNumber: String,
        buildNumber: String,
        appName: String,
        userName: String? = nil,
        environment: MetricsEnvironment = .staging,
        completion: @escaping (Result<String, MetricsError>) -> Void
    ) async
    
    /// Collects device metrics
    @MainActor
    public func collectMetrics() throws -> DeviceMetrics
}
```

### MetricsEnvironment

```swift
public enum MetricsEnvironment {
    case develop(url: String)  // Custom development URL
    case test                  // Test environment
    case staging              // Staging environment (default)
    case prod                 // Production environment
}
```

### Touch Event Recording (iOS 17+)

```swift
@available(iOS 17, *)
public extension UIApplication {
    /// Enable touch event recording
    func recordTouches()
}
```

## Support

For questions, issues, or feature requests:

- 📧 Email: support@clickinsights.xyz
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/Lucia-iOS-SDK/issues)
- 📚 Documentation: [Full Documentation](https://docs.clickinsights.xyz)

## License

This SDK is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Changelog

### Version 1.0.0
- Initial release
- Device fingerprinting
- Touch event tracking (iOS 17+)
- Event batching with offline support
- Multi-environment support

---

Made with ❤️ by the Lucia team
