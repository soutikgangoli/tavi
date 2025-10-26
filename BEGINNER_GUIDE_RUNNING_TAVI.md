# Complete Beginner's Guide: Running Tavi in Xcode

This guide assumes you've never used Xcode before. Follow each step carefully!

---

## Part 1: Opening Your Project (You've Already Done This! ✅)

The project should already be open in Xcode. You should see a window with lots of files on the left side.

---

## Part 2: Understanding the Xcode Window

Let me explain what you're looking at:

```
┌─────────────────────────────────────────────────────────────┐
│  [▶︎ Build/Run Button]  Tavi > iPhone 15 Pro     [Top Bar]  │
├──────────┬──────────────────────────────────────────────────┤
│          │                                                   │
│  File    │         Code Editor                              │
│  List    │         (This is where you see Swift code)       │
│  (Left)  │                                                   │
│          │                                                   │
│          │                                                   │
├──────────┴──────────────────────────────────────────────────┤
│  Bottom Panel (Errors/Warnings will show here)              │
└─────────────────────────────────────────────────────────────┘
```

**Key Areas:**
- **Left Side (Navigator)**: List of all your files
- **Middle (Editor)**: Where you view/edit code
- **Top Bar**: Build/Run controls and device selection
- **Bottom Panel**: Shows errors, warnings, and build progress

---

## Part 3: Building the Project (Finding Errors)

### Step 1: Build the Project

1. **Look at the top-left of Xcode** - You'll see a **Play button (▶︎)**
2. **FIRST, just press `Command ⌘ + B`** (or click Product → Build in the menu)
   - This compiles the code without running it
   - This is how we find problems!

### Step 2: Watch the Build Process

You'll see at the top of Xcode:
```
Building... [Progress bar]
```

**What can happen:**
- ✅ **"Build Succeeded"** (green checkmark) - Perfect! No errors!
- ❌ **"Build Failed"** (red X) - There are errors we need to fix

### Step 3: Finding Errors and Warnings

If the build fails or has warnings:

**Option A: Issue Navigator (Recommended for Beginners)**
1. Look at the **left sidebar**
2. Click the **⚠️ icon** (looks like a triangle with an exclamation mark)
3. This shows ALL errors and warnings in one place
4. Each error is listed with:
   - ❌ Red circle = ERROR (must fix)
   - ⚠️ Yellow triangle = WARNING (should fix, but might work)

**Option B: Bottom Panel**
1. If you don't see a panel at the bottom, press `Command ⌘ + Shift + Y`
2. This shows build output and errors inline

### Step 4: Understanding Error Messages

Click on any error to see:
- **File name**: Where the error is
- **Line number**: Exact location
- **Error message**: What's wrong
- **Fix-it suggestions**: Xcode often suggests fixes!

**Common error types you might see:**

```
❌ "Cannot find 'SomeType' in scope"
   → Missing import or file not added to project

❌ "Use of unresolved identifier 'xyz'"
   → Variable/function doesn't exist

⚠️ "Immutable value was never used"
   → Unused variable (warning, not critical)
```

---

## Part 4: Fixing Common Build Issues

### Issue #1: Files Not in Target

**Symptom:** "Cannot find type X in scope" even though the file exists

**Fix:**
1. Click on the file in the left sidebar that has the missing type
2. Look at the **right sidebar** (if not visible, press `Command ⌘ + Option ⌥ + 1`)
3. Under "Target Membership", make sure **"Tavi" has a checkmark** ✅
4. If no checkmark, click the empty box to add it

### Issue #2: Missing Assets.xcassets

**Symptom:** Build error about missing asset catalog

**Fix:**
We need to create it:
1. Right-click on "Tavi" folder in left sidebar
2. Select "New File..."
3. Choose "Asset Catalog"
4. Name it "Assets" and click Create

### Issue #3: Missing Core Data Model

**Symptom:** Error in PersistenceController about missing model

**We'll fix this if it comes up - let me know!**

---

## Part 5: Selecting a Simulator

Before running, choose what device to simulate:

### Step 1: Click the Device Selector
1. Look at the **top-center** of Xcode
2. You'll see something like: `Tavi > My Mac (Designed for iPad)`
3. **Click on the device name** (the part after `>`)

### Step 2: Choose an iPhone Simulator
A dropdown menu appears. Choose:
- **iPhone 15 Pro** (recommended)
- **iPhone 14 Pro** (also good)
- Any iPhone 12 or newer

**Important:**
- ⚠️ Camera features won't work in simulator (simulator has no camera)
- ✅ You can still test the UI and navigation
- 🎯 For full testing, you'll need a real iPhone later

### Step 3: Verify Selection
After clicking, the top bar should show:
```
Tavi > iPhone 15 Pro
```

---

## Part 6: Running the App

### Step 1: Press the Run Button
1. Click the **Play button ▶︎** at the top-left
   - Or press `Command ⌘ + R`

### Step 2: Wait for Build + Launch
You'll see several stages:

```
1. "Building Tavi..." (30 seconds - 2 minutes first time)
2. "Running Tavi..."
3. "Build Succeeded"
4. Simulator launches automatically
```

**Be patient on first run!** It can take 1-2 minutes.

### Step 3: Simulator Opens
- A new window appears (looks like an iPhone)
- The app launches inside it
- You can interact with it using your mouse/trackpad

---

## Part 7: What to Expect When Tavi Runs

### First Launch: Onboarding Screen

You should see:
1. **Onboarding welcome screen**
   - This is defined in `OnboardingView.swift`
   - Should have welcome message and "Get Started" button
   - Tap to continue

### After Onboarding: Main Menu

You'll see a list with sections:

```
┌─────────────────────────┐
│ Tavi                    │
├─────────────────────────┤
│ Features                │
│  📊 Analysis History    │
│  🔨 Debug Screen        │
│                         │
│ Settings                │
│  📷 Capture Settings    │
│  ℹ️  Device Info         │
│                         │
│ Device                  │
│  Model: iPhone 15 Pro   │
│  Chip: A17 Pro          │
│                         │
│ App Info                │
│  Version: 1.0.0         │
└─────────────────────────┘
```

### Testing Each Feature:

#### 1. Analysis History
- Tap "Analysis History"
- Should show empty state (no results yet)
- Message: "No analysis sessions yet"

#### 2. Debug Screen (Main Camera Feature)
- Tap "Debug Screen"
- **In Simulator:** Will show error/placeholder (no camera available)
- **On Real Device:** Will ask for camera permission, then show camera feed

#### 3. Capture Settings
- Tap "Capture Settings"
- Shows configuration options for capture quality
- You can toggle settings

#### 4. Device Info
- Tap "Device Info"
- Shows technical capabilities
- Lists what your device supports

---

## Part 8: Testing on a Real iPhone (Camera Testing)

Camera features **require a real device**. Here's how:

### Step 1: Connect Your iPhone
1. Plug iPhone into your Mac via USB cable
2. **On iPhone:** Tap "Trust This Computer" when prompted
3. Enter your iPhone passcode

### Step 2: Select Your iPhone in Xcode
1. Click device selector at top (where it says "iPhone 15 Pro")
2. Under "iOS Devices", you'll see your iPhone name
3. Click it to select

### Step 3: Enable Developer Mode on iPhone
**iOS 16+ requires this:**
1. On your iPhone, go to: **Settings → Privacy & Security → Developer Mode**
2. Toggle "Developer Mode" ON
3. Restart your iPhone when prompted
4. After restart, confirm when asked

### Step 4: Run on Device
1. Press Play ▶︎ in Xcode
2. First time: Xcode will install some tools (takes a minute)
3. App installs and launches on your iPhone!

### Step 5: Grant Camera Permission
When you tap "Debug Screen":
1. iOS asks: **"Tavi would like to access the Camera"**
2. Tap **"OK"** or **"Allow"**
3. Camera feed should appear!
4. Point at your face - you should see face detection landmarks

---

## Part 9: Understanding Build Progress and Logs

### Reading the Build Output

Press `Command ⌘ + 9` to see the **Report Navigator**:
- Shows history of all builds
- Click latest build to see details
- Useful for debugging tricky errors

### Console Output (While Running)

Press `Command ⌘ + Shift + Y` to show **Debug Console**:
- Shows `print()` statements from code
- Shows runtime errors
- Useful for tracking app behavior

---

## Part 10: Common Problems & Solutions

### Problem: "Signing for Tavi requires a development team"

**What it means:** Need Apple Developer account to run on device

**Solution:**
1. Click on **"Tavi"** (blue icon) at top of file list
2. Under "Signing & Capabilities" tab
3. Check **"Automatically manage signing"**
4. Select your Apple ID under "Team"
   - If no team, click "Add Account..." and sign in with Apple ID
   - Free Apple ID works for testing!

### Problem: App crashes immediately

**Check console for errors:**
1. Open Debug Console (`Cmd + Shift + Y`)
2. Look for red error messages
3. Common issues:
   - Missing Core Data model
   - Permission not granted
   - File missing from target

### Problem: "Module not found" error

**Solution:**
1. File → Packages → Resolve Package Versions
2. Wait for Swift Package Manager to download dependencies
3. Build again

### Problem: Simulator is slow

**Solution:**
1. Choose a newer simulator (iPhone 15 Pro)
2. Quit other apps to free memory
3. Or test on real device (much faster!)

---

## Part 11: Quick Reference - Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build | `⌘ + B` |
| Run | `⌘ + R` |
| Stop | `⌘ + .` (period) |
| Clean Build | `⌘ + Shift + K` |
| Show/Hide Console | `⌘ + Shift + Y` |
| Show/Hide Navigator | `⌘ + 0` |
| Find in Project | `⌘ + Shift + F` |
| Show Issues | `⌘ + 5` |

---

## Part 12: Expected App Behavior Summary

### ✅ What SHOULD Work (Simulator or Device):
- App launches without crashing
- Onboarding screen displays and can be dismissed
- Main menu navigation works
- Settings screens open and display
- Device info shows correct details
- UI is responsive and smooth

### ⚠️ What WON'T Work in Simulator:
- Camera feed (no camera in simulator)
- Face detection in real-time
- Capturing actual analysis sessions
- Testing camera calibration

### 🎯 What Requires Real Device:
- Camera capture
- Face landmark detection
- Full skin analysis workflow
- Saving analysis results with photos
- Testing actual metrics calculation

---

## Your First Test Checklist

Use this checklist for your first run:

- [ ] Project builds without errors (`⌘ + B`)
- [ ] Simulator/device selected at top
- [ ] App launches (`⌘ + R`)
- [ ] Onboarding screen appears
- [ ] Can dismiss onboarding
- [ ] Main menu displays correctly
- [ ] Can navigate to "Analysis History" (shows empty state)
- [ ] Can navigate to "Debug Screen" (shows camera placeholder or camera feed)
- [ ] Can navigate to "Capture Settings"
- [ ] Can navigate to "Device Info"
- [ ] Device info shows correct device name
- [ ] App doesn't crash when navigating

---

## What to Do Next

### If Everything Works:
1. ✅ Test all navigation flows
2. ✅ Connect real iPhone to test camera
3. ✅ Try capturing a session with your face
4. ✅ Check if analysis results are saved
5. ✅ Test the debug screen features

### If You Get Errors:
1. ❌ Take a screenshot of the error
2. ❌ Note which file and line number
3. ❌ Copy the exact error message
4. ❌ Tell me the error - I'll help you fix it!

---

## Need Help?

**When asking for help, provide:**
1. What step you're on
2. What you expected to happen
3. What actually happened
4. Screenshot of any errors
5. The exact error message (if any)

**Example:**
> "I'm on Part 6, Step 1. When I press the Run button, I get a build error that says 'Cannot find type PersistenceController in scope' in TaviApp.swift line 12. Screenshot attached."

---

## Quick Troubleshooting Decision Tree

```
Did the build succeed?
├─ YES → Did the app launch?
│  ├─ YES → Does navigation work?
│  │  ├─ YES → ✅ Success! Move to camera testing
│  │  └─ NO → Check console for errors (⌘+Shift+Y)
│  └─ NO → Check crash logs and console
└─ NO → Check Issue Navigator (⌘+5) for errors
```

---

**Ready to start? Begin with Part 3, Step 1!**

Press `⌘ + B` and tell me what happens! 🚀
