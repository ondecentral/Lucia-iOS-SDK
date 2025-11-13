# Changelog

All notable changes to the Lucia Metrics SDK for iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-12

### Added
- Initial release of Lucia Metrics SDK for iOS
- Device fingerprinting with IDFA and IDFV support
- App Tracking Transparency (ATT) framework integration
- Touch event tracking for iOS 17+
- Event batching with configurable size and time limits
- Offline event storage with automatic retry
- Network-aware event synchronization
- Multi-environment support (develop, test, staging, prod)
- Comprehensive error handling with MetricsError enum
- Async/await support for iOS 15+
- Automatic session management
- User identification support
- Device metrics collection (IP, model, OS version)
- SwiftUI and UIKit support
- Persistent event storage using FileEventStorage
- Network monitoring with SystemNetworkMonitor
- Automatic event flushing on app lifecycle events
- SHA256 hash generation for session IDs
- User-Agent generation for API requests
- Touch event types: tap, fling/swipe, scroll/drag

### Documentation
- Comprehensive README with installation and usage instructions
- Quick Start guide for rapid integration
- Complete API documentation
- Code examples for UIKit and SwiftUI
- Troubleshooting guide
- Best practices documentation

### Developer Features
- Swift 6.1 support
- iOS 14+ deployment target
- Swift Package Manager integration
- Unit test support
- @MainActor annotations for thread safety
- Sendable conformance for concurrency safety
- Proper access control (public API surface)

## [Unreleased]

### Planned Features
- [ ] SwiftData integration for advanced event storage
- [ ] Custom event types support
- [ ] Event filtering and sampling
- [ ] Real-time event streaming
- [ ] Enhanced privacy controls
- [ ] GDPR compliance helpers
- [ ] Advanced analytics dashboard integration
- [ ] A/B testing support
- [ ] User segmentation
- [ ] Performance monitoring
- [ ] Crash reporting integration
- [ ] Custom metric definitions
- [ ] Event validation and schema enforcement
- [ ] Compression for large payloads
- [ ] Request prioritization
- [ ] Background upload support
- [ ] Widget support
- [ ] Apple Watch support
- [ ] macOS support
- [ ] iPadOS optimization

### Known Issues
- None at this time

## Migration Guides

### From Pre-release to 1.0.0

This is the first stable release. If you were using a pre-release version:

1. Update your Package.swift to version 1.0.0
2. Ensure your Info.plist contains `LuciaSDKKey`
3. Add `NSUserTrackingUsageDescription` to Info.plist
4. Update initialization code to use the new async API
5. Replace any deprecated methods with their new equivalents

## Version Numbering

We use Semantic Versioning:
- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality in a backwards compatible manner
- **PATCH** version for backwards compatible bug fixes

## Support

For questions about this release or migration help:
- 📧 Email: support@clickinsights.xyz
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/Lucia-iOS-SDK/issues)

---

[1.0.0]: https://github.com/your-org/Lucia-iOS-SDK/releases/tag/v1.0.0
[Unreleased]: https://github.com/your-org/Lucia-iOS-SDK/compare/v1.0.0...HEAD
