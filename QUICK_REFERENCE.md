# Lucia iOS SDK - Quick Reference

## 🚀 Installation

```bash
# Swift Package Manager
https://github.com/your-org/Lucia-iOS-SDK.git
```

## ⚙️ Configuration

### Info.plist
```xml
<key>LuciaSDKKey</key>
<string>YOUR_API_KEY_HERE</string>

<key>NSUserTrackingUsageDescription</key>
<string>We use this to provide personalized analytics.</string>
```

## 📱 Basic Usage

### Import
```swift
import LuciaMetricsSDK
```

### Initialize
```swift
Task { @MainActor in
    await MetricsCollector.shared.captureDeviceFingerprint(
        versionNumber: "1.0.0",
        buildNumber: "1",
        appName: "MyApp",
        userName: "user@example.com",  // Optional
        environment: .staging
    ) { result in
        switch result {
        case .success(let lid):
            print("✅ Initialized: \(lid)")
        case .failure(let error):
            print("❌ Error: \(error)")
        }
    }
}
```

## 🌍 Environments

```swift
.develop(url: "https://custom.com")  // Custom dev URL
.test                                 // Test environment
.staging                              // Staging (default)
.prod                                 // Production
```

## 👆 Touch Events (iOS 17+)

```swift
// After initialization
UIApplication.shared.recordTouches()
```

## ⚠️ Errors

```swift
.permissionDenied      // User denied tracking
.networkUnavailable    // No network
.syncFailed(error)     // Backend sync failed
.unknown               // Unknown error
```

## 🔑 Common Patterns

### UIKit Setup
```swift
// AppDelegate.swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions...) -> Bool {
    initializeLucia()
    return true
}

private func initializeLucia() {
    Task { @MainActor in
        await MetricsCollector.shared.captureDeviceFingerprint(
            versionNumber: "1.0.0",
            buildNumber: "1",
            appName: "MyApp"
        ) { result in
            // Handle result
        }
    }
}
```

### SwiftUI Setup
```swift
@main
struct MyApp: App {
    init() {
        initializeLucia()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Get Bundle Info
```swift
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
```

### Async/Await (iOS 15+)
```swift
let syncer = MetricsSyncer(
    versionNumber: "1.0.0",
    buildNumber: "1",
    appName: "MyApp",
    fingerprint: "fingerprint",
    environment: .staging
)

let lid = try await syncer.initializeSDK()
```

## 📊 Metrics Collected

- **device_id**: IDFA (with permission)
- **idfv**: Identifier for Vendor
- **ip_address**: Current IP address
- **device_model**: e.g., "iPhone"
- **os_version**: iOS version number

## 🎯 Best Practices

1. ✅ Initialize early (AppDelegate/App init)
2. ✅ Use .staging for testing
3. ✅ Handle all error cases
4. ✅ Request permission explicitly
5. ✅ Enable touch tracking after init
6. ✅ Log errors for debugging

## 📚 Documentation

- **README.md** - Complete guide
- **QUICKSTART.md** - 5-minute setup
- **API_DOCUMENTATION.md** - Full API reference
- **EXAMPLES.md** - Code examples
- **CHANGELOG.md** - Version history

## 🐛 Troubleshooting

### "API Key Not Found"
→ Add `LuciaSDKKey` to Info.plist

### "Permission Denied"
→ Add `NSUserTrackingUsageDescription` to Info.plist

### "Network Error"
→ SDK auto-retries when network available

### "Touch Events Not Recording"
→ Requires iOS 17+, call after initialization

## 💡 Tips

- Use `.staging` for development
- Switch to `.prod` for App Store
- Username is optional
- Touch tracking requires iOS 17+
- Events batch automatically
- Offline events sync when online

## 📞 Support

- 📧 support@clickinsights.xyz
- 🐛 GitHub Issues
- 📚 Full docs included

---

**Version**: 1.0.0 | **Platform**: iOS 14+ | **Swift**: 6.1+
