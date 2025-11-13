# Lucia Metrics SDK - Quick Start Guide

Get up and running with the Lucia Metrics SDK in just a few minutes!

## Step 1: Install the SDK

Add the SDK to your project via Swift Package Manager:

1. In Xcode: **File > Add Package Dependencies...**
2. Paste the repository URL
3. Click **Add Package**

## Step 2: Get Your API Key

1. Sign up at [clickinsights.xyz](https://clickinsights.xyz)
2. Create a new project
3. Copy your API key

## Step 3: Configure Your App

Add your API key to `Info.plist`:

```xml
<key>LuciaSDKKey</key>
<string>YOUR_API_KEY_HERE</string>
```

Add tracking permission description:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use this to provide personalized analytics.</string>
```

## Step 4: Initialize the SDK

### For UIKit Apps

Add to your `AppDelegate.swift`:

```swift
import UIKit
import LuciaMetricsSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        initializeLucia()
        return true
    }
    
    private func initializeLucia() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",      // Your app version
                buildNumber: "1",            // Your build number
                appName: "MyAwesomeApp",     // Your app name
                userName: nil,               // Optional user identifier
                environment: .staging        // Use .staging for testing
            ) { result in
                switch result {
                case .success(let deviceId):
                    print("✅ Lucia initialized! Device ID: \(deviceId)")
                    
                case .failure(let error):
                    print("❌ Failed to initialize: \(error)")
                }
            }
        }
    }
}
```

### For SwiftUI Apps

Add to your main `App` file:

```swift
import SwiftUI
import LuciaMetricsSDK

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
    
    private func initializeLucia() {
        Task { @MainActor in
            await MetricsCollector.shared.captureDeviceFingerprint(
                versionNumber: "1.0.0",
                buildNumber: "1",
                appName: "MyAwesomeApp",
                environment: .staging
            ) { result in
                if case .success(let deviceId) = result {
                    print("✅ Lucia initialized! Device ID: \(deviceId)")
                }
            }
        }
    }
}
```

## Step 5: Test Your Integration

1. Run your app in the simulator or on a device
2. Check the Xcode console for:
   ```
   ✅ Lucia initialized! Device ID: xxx-xxx-xxx
   ```
3. Visit your dashboard at [clickinsights.xyz](https://clickinsights.xyz) to see the data

## Step 6: Enable Touch Tracking (Optional, iOS 17+)

To track user touch interactions:

```swift
// After successful initialization
if case .success = result {
    if #available(iOS 17, *) {
        UIApplication.shared.recordTouches()
        print("✅ Touch tracking enabled")
    }
}
```

## Step 7: Go to Production

When ready for production:

1. Change environment to `.prod`:
   ```swift
   environment: .prod
   ```

2. Update your API key in `Info.plist` to your production key

3. Test thoroughly in TestFlight before releasing!

## That's It! 🎉

You're now tracking device metrics and user behavior with Lucia!

## Next Steps

- **Customize**: Add username/email for user-specific tracking
- **Monitor**: Check your dashboard for real-time analytics
- **Optimize**: Use the insights to improve your app

## Getting Help

- 📚 [Full Documentation](../README.md)
- 🐛 [Report Issues](https://github.com/your-org/Lucia-iOS-SDK/issues)
- 💬 [Support](mailto:support@clickinsights.xyz)

## Common Issues

### "API Key Not Found"
✅ Make sure you added `LuciaSDKKey` to `Info.plist`

### "Permission Denied"
✅ Add `NSUserTrackingUsageDescription` to `Info.plist`

### "Not Seeing Data in Dashboard"
✅ Check you're using the correct environment (staging vs prod)
✅ Verify your API key is correct
✅ Check console for error messages

---

Happy tracking! 🚀
