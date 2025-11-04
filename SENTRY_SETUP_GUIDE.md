# 🔧 Sentry Crash Reporting Setup Guide

## Overview

This guide walks you through configuring Sentry crash reporting for the Tavi app. Crash reporting is **essential for production** to diagnose user issues and prevent future crashes.

---

## ⚡ Quick Setup (5 minutes)

### Step 1: Create Sentry Account

1. Go to https://sentry.io
2. Click "Sign Up" (free tier available - includes 5,000 errors/month)
3. Create your account

### Step 2: Create iOS Project

1. In Sentry dashboard, click "Projects" → "Create Project"
2. Select **"iOS"** as platform
3. Name your project: `tavi-ios`
4. Click "Create Project"

### Step 3: Get Your DSN

After creating the project, you'll see a DSN that looks like:

```
https://abc123def456@o123456.ingest.sentry.io/123456
```

**Copy this DSN** - you'll need it in the next step.

### Step 4: Add DSN to Xcode Project

#### Option A: Info.plist (Recommended for Production)

1. Open `Tavi.xcodeproj` in Xcode
2. Open `Info.plist`
3. Add a new row:
   - **Key:** `SENTRY_DSN`
   - **Type:** String
   - **Value:** (paste your DSN from Step 3)

#### Option B: Environment Variable (For Development/Testing)

1. In Xcode, go to: Product → Scheme → Edit Scheme
2. Select "Run" from left sidebar
3. Go to "Arguments" tab
4. Under "Environment Variables", click "+"
5. Add:
   - **Name:** `SENTRY_DSN`
   - **Value:** (paste your DSN from Step 3)

### Step 5: Verify Setup

1. Build and run the app in Xcode
2. Check the console output for:
   ```
   📊 CrashReporter: Production mode - Sentry enabled
      DSN: https://abc123def456...
   ```

3. Test crash reporting (optional):
   - Add this temporary button anywhere in your UI:
   ```swift
   Button("Test Crash") {
       fatalError("Test crash for Sentry")
   }
   ```
   - Tap the button
   - Restart the app
   - Check Sentry dashboard - crash should appear within 1 minute

4. **Remove the test crash button before releasing!**

---

## 📊 What Gets Reported

### Automatically Tracked:

- ✅ **Crashes** - Fatal errors that terminate the app
- ✅ **Non-fatal errors** - Scan failures, processing errors, etc.
- ✅ **Performance metrics** - 20% of user sessions sampled
- ✅ **Session tracking** - App opens, duration, crashes per session
- ✅ **Device context** - iOS version, device model, memory usage
- ✅ **Release tracking** - App version and build number

### Manually Logged:

- ✅ **User actions** - Scan started, settings changed, etc.
- ✅ **Scan errors** - Lighting issues, pose problems, processing failures
- ✅ **Context breadcrumbs** - User flow leading up to crash

### NOT Tracked:

- ❌ User personal information (email, name, etc.)
- ❌ Face images or scan data
- ❌ Location data
- ❌ Contacts or photos

---

## 🔍 Monitoring in Sentry Dashboard

### Key Metrics to Watch:

1. **Issues** - Unique errors grouped by type
2. **Crash-free rate** - % of sessions without crashes (aim for >99%)
3. **Performance** - App load time, scan processing time
4. **Release Health** - Compare stability across versions

### Setting Up Alerts:

1. In Sentry dashboard, go to "Alerts"
2. Create alert rules:
   - **High Priority:** Crash rate > 1% for any release
   - **Medium Priority:** New unique error appears
   - **Low Priority:** Performance degradation detected

3. Configure notifications:
   - Email
   - Slack (recommended for team)
   - PagerDuty (for critical issues)

---

## 🚨 If DSN Not Configured

### Debug Mode (Development):
```
⚠️ Sentry DSN not configured. Crash reporting disabled in DEBUG mode.
   To enable:
   1. Sign up at https://sentry.io
   2. Create a new iOS project
   3. Add SENTRY_DSN to environment variables or Info.plist
```

### Production Build:
```
❌ CRITICAL: Sentry DSN not configured in PRODUCTION build!
   Crash reporting is DISABLED. This should not happen in production.
   Add SENTRY_DSN to Info.plist before releasing to App Store.
```

**Note:** If you see the second message, **DO NOT RELEASE** to the App Store without configuring Sentry.

---

## 🔐 Security Best Practices

### 1. Keep DSN Private (But Not Secret)

- ✅ DSN is safe to commit to source control
- ✅ DSN is client-side key (visible in app binary)
- ⚠️ Anyone with DSN can send events to your project
- 💡 Use Sentry's rate limiting to prevent abuse

### 2. Filter Sensitive Data

The app automatically filters:
- User cancellation errors (intentional)
- Personal information (not collected)

To add more filters, edit `CrashReporter.swift:115-122`:

```swift
options.beforeSend = { event in
    // Add custom filtering here
    return event
}
```

### 3. User Privacy

Sentry is configured to:
- ✅ Use anonymous user IDs (UUID, not email)
- ✅ Not collect personal data
- ✅ Comply with GDPR/CCPA when properly configured

---

## 📱 Testing Before Release

### Checklist:

- [ ] DSN configured in Info.plist
- [ ] Test crash report received in Sentry dashboard
- [ ] Verify release version shows correctly (Settings → About)
- [ ] Check session tracking works (open/close app 3 times)
- [ ] Test scan error reporting (force a scan failure)
- [ ] Verify performance metrics appear in dashboard
- [ ] Set up alerts for crash rate > 1%
- [ ] Remove any test crash buttons from code

---

## 💰 Pricing & Limits

### Free Tier (Good for MVP/Beta):
- 5,000 errors/month
- 10,000 performance units/month
- 30-day data retention
- Community support

### Paid Plans:
- **Team:** $26/month - 50k errors, 100k performance
- **Business:** $80/month - 150k errors, 300k performance
- **Enterprise:** Custom pricing

**Tip:** Start with free tier. You can always upgrade if you exceed limits.

---

## 🐛 Troubleshooting

### Issue: "Sentry SDK not available"

**Solution:** Add Sentry package dependency:
1. File → Add Package Dependencies
2. Enter: `https://github.com/getsentry/sentry-cocoa.git`
3. Select latest version
4. Add to Tavi target

### Issue: No crashes appearing in dashboard

**Checklist:**
- [ ] DSN is correct (check for typos)
- [ ] Internet connection available
- [ ] Restarted app after crash (crashes sent on next launch)
- [ ] Check Sentry project's inbound filters (may be blocking events)
- [ ] Look in console for "📊 CrashReporter" messages

### Issue: Too many events

**Solutions:**
1. Adjust sample rate in `CrashReporter.swift:101`:
   ```swift
   options.tracesSampleRate = 0.1  // Reduce to 10%
   ```

2. Add more aggressive filtering in `beforeSend` callback

3. Upgrade Sentry plan if needed

---

## 🎯 Success Criteria

You've successfully configured Sentry when:

1. ✅ Console shows: `📊 CrashReporter: Production mode - Sentry enabled`
2. ✅ Test crash appears in Sentry dashboard within 1 minute
3. ✅ Sessions show up in "Releases" tab
4. ✅ Release version matches app version (Settings → About)
5. ✅ Alerts are configured for crash rate > 1%

---

## 📚 Additional Resources

- **Sentry iOS Docs:** https://docs.sentry.io/platforms/apple/guides/ios/
- **Performance Monitoring:** https://docs.sentry.io/platforms/apple/performance/
- **Release Health:** https://docs.sentry.io/product/releases/health/
- **Best Practices:** https://docs.sentry.io/platforms/apple/best-practices/

---

## 🚀 Ready for Production?

Before submitting to App Store:

- [ ] ✅ Sentry DSN configured in Info.plist
- [ ] ✅ Crash reporting verified working
- [ ] ✅ Alerts configured
- [ ] ✅ Team has access to Sentry dashboard
- [ ] ✅ Privacy policy mentions crash reporting
- [ ] ✅ No test crash buttons in code

**Once complete, you're ready to ship! 🎉**

---

## 📞 Support

- **Sentry Support:** support@sentry.io
- **Documentation:** https://docs.sentry.io
- **Community:** https://discord.gg/sentry

---

*Last updated: 2025-01-04*
