# CRASH REPORTING INTEGRATION GUIDE

**Issue #15**: Integrate crash reporting for production monitoring

---

## **WHY CRASH REPORTING IS CRITICAL**

Without crash reporting, you cannot:
- Monitor production crashes and bugs
- Diagnose issues users encounter
- Track crash-free rates
- Prioritize bug fixes
- Understand failure patterns

**This is CRITICAL for any production app.**

---

## **RECOMMENDED SOLUTIONS**

### **Option 1: Firebase Crashlytics** (Recommended)
**Pros**:
- Free
- Easy integration
- Excellent reporting UI
- Part of Firebase ecosystem
- Automatic symbol upload

**Setup Time**: 1-2 hours

### **Option 2: Sentry**
**Pros**:
- More detailed error tracking
- Better for complex debugging
- Self-hosted option available
- Excellent React Native support

**Setup Time**: 2 hours

### **Option 3: Apple's Built-in Crash Reports**
**Pros**:
- Already integrated
- No setup required
- Free

**Cons**:
- Limited visibility
- Delayed reporting
- Requires App Store Connect access

---

## **FIREBASE CRASHLYTICS INTEGRATION** (Step-by-Step)

### **Step 1: Add Firebase to Your Project** (15 min)

1. Go to [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Create a new project or select existing
3. Add an iOS app
   - Bundle ID: `com.tavi.app` (or your bundle ID)
4. Download `GoogleService-Info.plist`
5. Add `GoogleService-Info.plist` to Xcode project root

### **Step 2: Install Firebase SDK via SPM** (10 min)

1. In Xcode: File → Add Packages
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: Latest (11.0.0+)
4. Add packages:
   - FirebaseCrashlytics
   - FirebaseAnalytics (optional but recommended)

### **Step 3: Initialize Firebase** (5 min)

Edit `/Users/apple/Desktop/Tavi/Tavi/TaviApp.swift`:

```swift
import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct TaviApp: App {

    init() {
        // Initialize Firebase
        FirebaseApp.configure()

        // Enable automatic crash collection
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\\.managedObjectContext, PersistenceController.shared.viewContext)
        }
    }
}
```

### **Step 4: Update Build Settings** (10 min)

1. In Xcode, select your target
2. Build Phases → + → New Run Script Phase
3. Add script:

```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

4. Input Files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

### **Step 5: Test Crash Reporting** (5 min)

Add test crash button (remove before production):

```swift
import FirebaseCrashlytics

Button("Test Crash") {
    fatalError("Test crash for Firebase Crashlytics")
}
```

### **Step 6: Log Non-Fatal Errors** (10 min)

Update error handlers to log to Crashlytics:

```swift
// In error handling code
catch {
    // Log to Crashlytics
    Crashlytics.crashlytics().record(error: error)

    // Show user-friendly message
    errorMessage = "An error occurred. Please try again."
}
```

### **Step 7: Add Custom Logging** (5 min)

```swift
// In key operations
Crashlytics.crashlytics().log("Starting face scan")

// Add user attributes
Crashlytics.crashlytics().setUserID(userID)

// Add custom keys
Crashlytics.crashlytics().setCustomValue(scanCount, forKey: "total_scans")
```

### **Step 8: Verify Integration** (10 min)

1. Run app in debug mode
2. Trigger test crash
3. Reopen app
4. Check Firebase Console (Crashlytics section)
5. Should see crash within 5 minutes

---

## **KEY INTEGRATION POINTS IN TAVI**

### **Where to Add Crashlytics Logging**:

1. **EmotionalScan3DFlowView.swift** (lines 334-368)
   ```swift
   } catch let scanError as ScanError {
       Crashlytics.crashlytics().record(error: scanError)
       // existing error handling
   }
   ```

2. **FaceScan3DViewModel.swift** (Session failures)
   ```swift
   func sessionFailed(error: Error) {
       Crashlytics.crashlytics().record(error: error)
       // existing handling
   }
   ```

3. **ResultsViewModel.swift** (Storage errors)
   ```swift
   catch {
       Crashlytics.crashlytics().record(error: error)
       errorMessage = "Unable to load..."
   }
   ```

4. **PersistenceController.swift** (CoreData errors)
   ```swift
   if let error = loadError {
       Crashlytics.crashlytics().record(error: error)
       throw PersistenceError.coreDataStackFailed(error)
   }
   ```

---

## **CUSTOM CRASH KEYS TO ADD**

```swift
// At app launch
Crashlytics.crashlytics().setCustomValue(
    UIDevice.current.model,
    forKey: "device_model"
)

Crashlytics.crashlytics().setCustomValue(
    UIDevice.current.systemVersion,
    forKey: "ios_version"
)

// During scan
Crashlytics.crashlytics().setCustomValue(
    scanCount,
    forKey: "lifetime_scans"
)

Crashlytics.crashlytics().setCustomValue(
    currentPose,
    forKey: "current_pose"
)
```

---

## **PRODUCTION CHECKLIST**

- [ ] Firebase project created
- [ ] GoogleService-Info.plist added
- [ ] Firebase SDK installed via SPM
- [ ] Firebase initialized in TaviApp.swift
- [ ] Build script added for symbol upload
- [ ] Error logging added to catch blocks
- [ ] Custom keys configured
- [ ] Test crash verified in Firebase Console
- [ ] Test button removed before release
- [ ] Privacy policy updated (crash reporting disclosure)

---

## **PRIVACY CONSIDERATIONS**

**Must Update**:
1. Privacy policy - Disclose crash data collection
2. App Store privacy nutrition label
   - Analytics → Crash Data
   - Not linked to user identity

**Firebase Crashlytics collects**:
- Crash stack traces
- Device model/OS
- Custom keys you set
- Does NOT collect: Personal information, scan photos, health data

---

## **ALTERNATIVE: SENTRY INTEGRATION**

If you prefer Sentry over Firebase:

### **Quick Setup**:

1. Create account at [https://sentry.io](https://sentry.io)
2. Add Sentry SPM:
   ```
   https://github.com/getsentry/sentry-cocoa
   ```
3. Initialize:
   ```swift
   import Sentry

   SentrySDK.start { options in
       options.dsn = "YOUR_DSN"
       options.debug = true // Only in debug
       options.tracesSampleRate = 1.0
   }
   ```
4. Capture errors:
   ```swift
   SentrySDK.capture(error: error)
   ```

---

## **COST COMPARISON**

| Solution | Free Tier | Paid Plans |
|----------|-----------|------------|
| Firebase Crashlytics | Unlimited | Free always |
| Sentry | 5K events/month | $26/month+ |
| Apple Built-in | Unlimited | Free (with App Store) |

**Recommendation**: Use Firebase Crashlytics (free, unlimited, excellent)

---

## **POST-INTEGRATION MONITORING**

Once integrated, monitor:
1. **Crash-free rate** - Target: >99.5%
2. **Most common crashes** - Fix high-frequency issues first
3. **Crash trends** - Watch for spikes after releases
4. **Device/OS distribution** - Identify problematic configurations

---

## **TIMELINE**

- **Firebase Setup**: 1-2 hours
- **Integration & Testing**: 30 minutes
- **Verification**: 15 minutes

**Total**: ~2-3 hours for complete integration

---

## **NEXT STEPS**

1. **Immediate**: Set up Firebase project
2. **Today**: Complete integration
3. **Before Launch**: Verify crashes appear in console
4. **Post-Launch**: Monitor daily for first week

---

**Note**: This integration should be completed **BEFORE** any public release or TestFlight beta. You cannot effectively support users without crash visibility.

---

**Created**: October 29, 2025
**Status**: Ready for implementation
**Priority**: CRITICAL for production launch
