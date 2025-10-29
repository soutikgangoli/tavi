# Sentry Integration Setup

## Overview
Tavi now uses Sentry for crash reporting and error tracking instead of Firebase Crashlytics.

## Why Sentry?
- Open-source and self-hostable
- Better privacy controls (EU hosting available)
- More detailed error context and breadcrumbs
- Performance monitoring included
- Free tier: 5,000 errors/month
- Better stack traces for Swift/iOS

## Setup Instructions

### 1. Create Sentry Account
1. Go to https://sentry.io
2. Sign up for free account
3. Create new iOS project
4. Copy your DSN (looks like: `https://xxx@yyy.ingest.sentry.io/zzz`)

### 2. Add Sentry SDK to Xcode

Open Xcode and add the Sentry package:

1. File → Add Package Dependencies
2. Enter URL: `https://github.com/getsentry/sentry-cocoa.git`
3. Version: Up to Next Major `8.0.0`
4. Add to target: **Tavi**
5. Select product: **Sentry**

### 3. Configure DSN

Add your Sentry DSN to environment or Info.plist:

**Option A: Environment Variable (Recommended for development)**
```bash
# In Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
SENTRY_DSN=https://your-dsn-here@sentry.io/project-id
```

**Option B: Info.plist (For production)**
```xml
<key>SENTRY_DSN</key>
<string>https://your-dsn-here@sentry.io/project-id</string>
```

### 4. Verify Integration

Build and run the app:
```bash
xcodebuild -project Tavi.xcodeproj -scheme Tavi -destination 'platform=iOS Simulator,name=iPhone 15' build
```

You should see in console:
```
📊 CrashReporter: Production mode - Sentry enabled
```

### 5. Test Error Reporting

To test Sentry is working, you can trigger a test crash:

```swift
// Add this temporarily to HomeView or any view
Button("Test Crash") {
    CrashReporter.shared.logError(
        ScanError.processingError("Test error from Tavi"),
        context: ["test": true, "timestamp": Date()]
    )
}
```

Check Sentry dashboard at https://sentry.io → Your Project → Issues

## Features Enabled

### Automatic Crash Detection
All unhandled exceptions and crashes are automatically reported.

### Non-Fatal Error Tracking
```swift
CrashReporter.shared.logError(
    error,
    context: ["operation": "mesh_merge", "frame_count": 120]
)
```

### User Context
```swift
CrashReporter.shared.setUserContext(
    userID: user.id.uuidString,
    metadata: ["skin_type": "oily", "scans_count": 42]
)
```

### Breadcrumbs
```swift
CrashReporter.shared.logUserAction("started_scan")
CrashReporter.shared.setCustomKey("lighting_level", value: 0.85)
```

### Performance Monitoring
- Automatic tracing of view loads
- 20% of transactions sampled (configurable in CrashReporter.swift:64)

## Configuration Options

Edit `/Tavi/Core/Utilities/CrashReporter.swift` to customize:

- **Sample Rate**: Line 64 - `options.tracesSampleRate = 0.2`
- **Environment**: Line 59 - `options.environment = "production"`
- **Error Filtering**: Lines 79-86 - `options.beforeSend` callback

## Cost & Limits

**Free Tier:**
- 5,000 errors/month
- 10,000 performance units/month
- 1 team member
- 30 days retention

**Team Plan ($26/month):**
- 50,000 errors/month
- 100,000 performance units
- Unlimited team members
- 90 days retention

Compare to Firebase Crashlytics:
- Firebase: Free but requires Google account, US-only hosting
- Sentry: Open-source, self-hostable, EU hosting, better privacy

## Privacy & Compliance

Sentry is GDPR compliant and offers:
- EU data hosting (select during project creation)
- Data scrubbing rules (remove PII automatically)
- User IP anonymization
- Export and deletion on request

Configure in Sentry dashboard:
Settings → Security & Privacy → Data Scrubbing

## Debugging

### Debug Mode
Enable Sentry in debug builds:
```bash
# Xcode: Edit Scheme → Run → Environment Variables
SENTRY_ENABLED=true
```

### Disable Sentry
To temporarily disable:
```swift
// In CrashReporter.swift:89
options.enabled = false
```

### View Local Logs
All errors are logged locally via OSLog even if Sentry is disabled:
```bash
# View logs in Console.app or:
log stream --predicate 'subsystem == "com.tavi.app"' --level debug
```

## Troubleshooting

**"Module 'Sentry' not found"**
- Ensure Sentry package is added via SPM
- Clean build folder: Cmd+Shift+K
- Rebuild: Cmd+B

**No errors appearing in Sentry**
- Check DSN is set correctly
- Verify network connection
- Check Sentry project is not paused

**Too many errors being reported**
- Adjust error filtering in `beforeSend` callback
- Increase sample rate threshold
- Add error type filters

## Next Steps

1. Add Sentry DSN to CI/CD pipeline
2. Set up alerts for critical errors
3. Configure release tracking with git commits
4. Set up source maps for better stack traces
5. Integrate with Slack/Discord for notifications

## Support

- Sentry Docs: https://docs.sentry.io/platforms/apple/
- Tavi-specific issues: Check CrashReporter.swift comments
