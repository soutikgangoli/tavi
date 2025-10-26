# Device Capabilities - Quick Reference

## 🎯 What It Does

Automatically detects iPhone model and hardware capabilities, enabling optimized features:

- ✅ **TrueDepth** → Face mesh overlay
- ✅ **4K Video** → High-res capture toggle
- ✅ **Neural Engine A16+** → Real-time processing
- ✅ **Graceful fallbacks** → Older devices still work

---

## 🚀 Quick Start

### Access Capabilities

```swift
let capabilities = DeviceCapabilities.current

// Check what device has
print(capabilities.deviceName)          // "iPhone 15 Pro"
print(capabilities.iPhoneModel.chipName) // "A17 Pro"
print(capabilities.supportsTrueDepth)    // true
print(capabilities.supports4KVideo)      // true
print(capabilities.supportsNeuralEngineA16Plus) // true
```

### Get Optimized Config

```swift
let config = capabilities.getOptimizedCaptureConfig()

print(config.resolution)       // .fourK / .fullHD / .hd720
print(config.frameRate)        // 60 / 30
print(config.processingMode)   // .realtime / .deferred
print(config.enableFaceMesh)   // true / false
```

---

## 📱 Supported Devices

### High-End (All Features)
- iPhone 16 series (A18)
- iPhone 15 Pro/Pro Max (A17 Pro)
- iPhone 14 Pro/Pro Max (A16)
- iPhone 15/15 Plus (A16)

**Capabilities**:
- ✅ Real-time processing
- ✅ 60 fps capture
- ✅ TrueDepth face mesh
- ✅ 4K video (Pro models only)

### Mid-Range (Most Features)
- iPhone 14/14 Plus (A15)
- iPhone 13 Pro (A15)

**Capabilities**:
- ⚡ Deferred processing
- ⚡ 30 fps capture
- ✅ TrueDepth face mesh
- ✅ 1080p video

### Older Devices (Basic Features)
- iPhone 12 Pro (A14)
- iPhone 11 Pro (A13)

**Capabilities**:
- ⚡ Deferred processing
- ⚡ 30 fps capture
- ✅ TrueDepth face mesh
- ⚡ 720p-1080p video

**Still Works**:
- Face detection
- Analysis
- All core features
- Just slower processing

---

## 🔍 Capability Checks

### Quick Queries

```swift
let caps = DeviceCapabilities.current

// Should show face mesh?
if caps.shouldEnableFaceMesh {
    // Show 3D mesh overlay
}

// Should show 4K toggle?
if caps.shouldShowHighResCaptureToggle {
    Toggle("High-Res Capture (4K)", isOn: $enable4K)
}

// Use real-time pipeline?
if caps.shouldUseRealtimePipeline {
    // Process immediately with Neural Engine
} else {
    // Queue for background processing
}

// Device tier
if caps.isHighEndDevice {
    // Enable all features
} else if caps.isLowEndDevice {
    // Optimize aggressively
}
```

---

## ⚙️ User Settings

**Already Integrated**:

Navigate to: **Settings → Capture Settings**

**Conditional Toggles**:

1. **High-Res Capture** (4K badge)
   - Shows only on: iPhone 15 Pro+
   - Enables: 4K front camera

2. **Face Mesh Overlay** (TrueDepth badge)
   - Shows only on: TrueDepth devices
   - Enables: 3D face mesh

3. **Real-time Processing** (A16+ badge)
   - Shows only on: A16+ devices
   - Enables: Instant processing

**Device Info**:

Navigate to: **Settings → Device Info**

Shows:
- Device model and chip
- Capability checkmarks
- Recommended settings
- Performance profile

---

## 💻 Integration Examples

### Adapt Camera Settings

```swift
class CameraManager {
    func configure() {
        let caps = DeviceCapabilities.current
        let config = caps.getOptimizedCaptureConfig()

        // Set resolution
        setCameraResolution(config.resolution.dimensions)

        // Set frame rate
        setFrameRate(config.frameRate)

        // Enable features if supported
        if caps.shouldEnableFaceMesh {
            enableFaceMesh()
        }
    }
}
```

### Conditional UI

```swift
VStack {
    // Always show
    StandardCaptureButton()

    // Only on capable devices
    if DeviceCapabilities.current.shouldShowHighResCaptureToggle {
        HighResToggle()
    }

    if DeviceCapabilities.current.shouldEnableFaceMesh {
        FaceMeshToggle()
    }
}
```

### Processing Pipeline

```swift
func processFrame(_ frame: CVPixelBuffer) {
    if DeviceCapabilities.current.shouldUseRealtimePipeline {
        // Real-time: A16+ devices
        neuralEngine.process(frame)
    } else {
        // Deferred: Older devices
        processingQueue.async {
            standardProcessor.process(frame)
        }
    }
}
```

---

## 📊 Capability Matrix

| Feature | iPhone 16 Pro | iPhone 15 | iPhone 14 | iPhone 13 |
|---------|--------------|-----------|-----------|-----------|
| **Chip** | A18 | A16 | A15 | A15 |
| **TrueDepth** | ✓ | ✓ | ✓ | ✓ |
| **4K Front** | ✓ | ✗ | ✗ | ✗ |
| **Neural A16+** | ✓ | ✓ | ✗ | ✗ |
| **Processing** | Real-time | Real-time | Deferred | Deferred |
| **FPS** | 60 | 60 | 30 | 30 |
| **Max Res** | 4K | 1080p | 1080p | 1080p |

---

## 🎛️ Settings Storage

```swift
// UserDefaults keys
@AppStorage("enableHighResCapture") var highRes = false
@AppStorage("enableFaceMesh") var faceMesh = true
@AppStorage("useRealtimeProcessing") var realtime = true

// Only enabled if device supports it
func applySettings() {
    let caps = DeviceCapabilities.current

    if highRes && !caps.supports4KVideo {
        highRes = false  // Fallback
    }

    if realtime && !caps.supportsNeuralEngineA16Plus {
        realtime = false  // Fallback
    }
}
```

---

## 🐛 Debug Info

```swift
// Print full device info
print(DeviceCapabilities.current.debugDescription)

// Example output:
// Device Capabilities:
// - Model: iPhone 15 Pro (iPhone15,2)
// - TrueDepth: ✓
// - 4K Video: ✓
// - Neural Engine A16+: ✓
// - Processing Mode: Real-time
// - Max Resolution: 4K (3840×2160)
// - Frame Rate: 60 fps
// - Concurrent Frames: 5
```

---

## ✅ Graceful Fallbacks

### What Happens on Older Devices?

**iPhone 13 (A15)**:
- ✗ Real-time processing → Deferred (slower)
- ✗ 4K capture → 1080p (still good)
- ✗ 60 fps → 30 fps (still smooth)
- ✅ All core features work
- ✅ TrueDepth face mesh
- ✅ Accurate analysis (just takes longer)

**iPhone 11 (A13)**:
- ✗ Real-time processing → Deferred
- ✗ High frame rate → 30 fps
- ✗ Full HD → 720p (acceptable)
- ✅ Still fully functional
- ✅ All analysis features
- ⚠️ Longer processing times

**User Experience**:
- No crashes or errors
- Clear messaging ("Optimized for your device")
- All features work, some just slower
- Settings hide unavailable options

---

## 🔧 Common Tasks

### Check Before Enabling Feature

```swift
if DeviceCapabilities.current.supportsTrueDepth {
    enableFaceMeshOverlay()
} else {
    showStandardFaceDetection()
}
```

### Get Recommended Settings

```swift
let config = DeviceCapabilities.current.getOptimizedCaptureConfig()
cameraManager.apply(config)
```

### Show Device-Specific Message

```swift
if DeviceCapabilities.current.isLowEndDevice {
    Text("Optimized for \(DeviceCapabilities.current.deviceName)")
        .foregroundColor(.orange)
}
```

### Conditional Feature Flag

```swift
let useFaceMesh = DeviceCapabilities.current.shouldEnableFaceMesh && userEnabledSetting
```

---

## 📁 Files

```
Tavi/
├── Core/ModelsKit/
│   └── DeviceCapabilities.swift         [NEW - 600+ lines]
│
├── Features/Settings/
│   ├── DeviceInfoView.swift             [NEW - 200+ lines]
│   └── CaptureSettingsView.swift        [NEW - 250+ lines]
│
├── ContentView.swift                    [UPDATED]
├── DEVICE_CAPABILITIES_IMPLEMENTATION.md [NEW - Full docs]
└── DEVICE_CAPABILITIES_QUICK_GUIDE.md   [NEW - This file]
```

---

## 🎉 Summary

**Device Capabilities**:
- ✅ Auto-detects iPhone model
- ✅ Identifies chip (A13-A18)
- ✅ Checks TrueDepth camera
- ✅ Checks 4K video support
- ✅ Checks Neural Engine A16+

**Smart Features**:
- ✅ Shows 4K toggle on capable devices
- ✅ Enables face mesh on TrueDepth devices
- ✅ Uses real-time processing on A16+
- ✅ Graceful fallbacks on older devices

**User Experience**:
- ✅ Settings auto-hide on incapable devices
- ✅ Clear capability indicators
- ✅ Performance profile shown
- ✅ All devices work (optimized per model)

**Usage**:
```swift
let caps = DeviceCapabilities.current
let config = caps.getOptimizedCaptureConfig()
```

That's it! Everything works automatically. 🚀
