# Device Capabilities Implementation

**Status**: ✅ COMPLETE

---

## Overview

Comprehensive device capability detection system that identifies iPhone models and their hardware features, enabling optimized app behavior and graceful fallbacks for older devices.

---

## Files Created

### 1. **DeviceCapabilities.swift** (600+ lines)
**Location**: `Tavi/Core/ModelsKit/DeviceCapabilities.swift`

**Purpose**: Core capability detection and device identification

**Features**:

#### **iPhone Model Detection**
Detects specific models:
- ✅ iPhone 16 series (2024) - A18 chip
- ✅ iPhone 15 series (2023) - A17 Pro / A16
- ✅ iPhone 14 series (2022) - A16 / A15
- ✅ iPhone 13 Pro (2021) - A15
- ✅ iPhone 12 Pro (2020) - A14
- ✅ iPhone 11 Pro (2019) - A13
- ✅ Simulator support
- ✅ Unknown device handling

**Detection Method**:
```swift
// Uses uname() system call to get model identifier
// Examples:
// iPhone15,2 → iPhone 15 Pro
// iPhone16,1 → iPhone 15 Pro (alternative identifier)
// iPhone17,1 → iPhone 16 Pro
```

#### **Hardware Capability Detection**

**1. TrueDepth Camera**
```swift
supportsTrueDepth: Bool
```
- Detects front-facing TrueDepth camera
- Required for face mesh overlay
- Available on iPhone X and newer (2017+)

**Detection**: Uses `AVCaptureDevice.DiscoverySession` with `.builtInTrueDepthCamera`

**2. 4K Video Capture**
```swift
supports4KVideo: Bool
```
- Checks if front camera supports 3840×2160 resolution
- Enables "High-Res Capture" toggle
- Available on iPhone 15 Pro and newer

**Detection**: Enumerates camera formats, checks dimensions

**3. Neural Engine A16+**
```swift
supportsNeuralEngineA16Plus: Bool
```
- Identifies devices with A16 chip or newer
- Enables real-time processing pipeline
- Available on:
  - iPhone 16 series (A18)
  - iPhone 15 Pro/Pro Max (A17 Pro)
  - iPhone 14 Pro/Pro Max (A16)
  - iPhone 15/15 Plus (A16)

**Detection**: Model-based identification

#### **Recommended Settings**

**Processing Mode**:
```swift
enum ProcessingMode {
    case realtime   // A16+ devices
    case deferred   // Older devices
}
```

**Capture Resolution**:
```swift
enum CaptureResolution {
    case fourK      // 3840×2160 (iPhone 15 Pro+)
    case fullHD     // 1920×1080 (iPhone 13+)
    case hd720      // 1280×720  (older devices)
}
```

**Frame Rate**:
- A16+: 60 fps
- Older: 30 fps

**Concurrent Frames**:
- A16+: 5 frames
- Older: 3 frames

#### **Performance Profiles**

**High-End Device**:
- Has A16+ Neural Engine
- Supports 4K video
- All features enabled
- Real-time processing

**Low-End Device**:
- iPhone 11 Pro or older
- Limited features
- Deferred processing
- Lower resolutions

**Balanced**:
- iPhone 12-14 standard models
- Good feature support
- Mixed processing modes

#### **Public API**

**Queries**:
```swift
DeviceCapabilities.current.shouldEnableFaceMesh              // Bool
DeviceCapabilities.current.shouldShowHighResCaptureToggle    // Bool
DeviceCapabilities.current.shouldUseRealtimePipeline         // Bool
DeviceCapabilities.current.isHighEndDevice                   // Bool
DeviceCapabilities.current.isLowEndDevice                    // Bool
```

**Info**:
```swift
DeviceCapabilities.current.deviceName                  // "iPhone 15 Pro"
DeviceCapabilities.current.modelIdentifier             // "iPhone15,2"
DeviceCapabilities.current.iPhoneModel.chipName        // "A17 Pro"
```

**Configuration**:
```swift
let config = DeviceCapabilities.current.getOptimizedCaptureConfig()
// Returns: CaptureConfig with all recommended settings
```

---

### 2. **DeviceInfoView.swift** (200+ lines)
**Location**: `Tavi/Features/Settings/DeviceInfoView.swift`

**Purpose**: Display device capabilities to user

**Sections**:

**1. Device**:
- Model name
- Chip name
- Model identifier

**2. Capabilities**:
- TrueDepth Camera ✓/✗
- 4K Video Capture ✓/✗
- Neural Engine A16+ ✓/✗

**3. Optimized Settings**:
- Processing mode
- Max resolution
- Frame rate
- Concurrent frames
- Footer: Explanation of auto-optimization

**4. Performance Profile**:
- Badge showing device tier
- High-End: Green bolt icon
- Balanced: Blue checkmark
- Optimized: Orange gauge

**UI Components**:
- `InfoRow`: Label-value pairs
- `CapabilityRow`: Capability with checkmark/X
- `PerformanceBadge`: Profile indicator with icon

---

### 3. **CaptureSettingsView.swift** (250+ lines)
**Location**: `Tavi/Features/Settings/CaptureSettingsView.swift`

**Purpose**: Capability-aware settings with feature toggles

**Feature Toggles** (conditional display):

**1. High-Res Capture** (4K devices only):
```swift
@AppStorage("enableHighResCapture") var enableHighResCapture = false
```
- Shows only if `capabilities.shouldShowHighResCaptureToggle`
- Badge: "4K" (teal)
- Footer: Battery/storage warning

**2. Face Mesh Overlay** (TrueDepth devices only):
```swift
@AppStorage("enableFaceMesh") var enableFaceMesh = true
```
- Shows only if `capabilities.shouldEnableFaceMesh`
- Badge: "TrueDepth" (blue)
- Footer: Explanation of TrueDepth usage

**3. Real-time Processing** (A16+ devices only):
```swift
@AppStorage("useRealtimeProcessing") var useRealtimeProcessing = true
```
- Shows only if `capabilities.supportsNeuralEngineA16Plus`
- Badge: "A16+" (green)
- Footer: Neural Engine explanation

**Performance Tips**:
- Shows device-specific recommendations
- Battery impact warnings
- Optimization suggestions

**Components**:
- `Badge`: Colored capability badge
- `TipCard`: Icon + title + description

---

### 4. **ContentView.swift** (Updated)
**Location**: `Tavi/ContentView.swift`

**Changes**: Added navigation to new settings

**New Sections**:
- Settings: Capture Settings, Device Info
- Device: Shows model name and chip

---

## Device Detection Logic

### Model Identifier Mapping

```swift
// iPhone 16 series (A18)
"iPhone17,1" → iPhone 16 Pro
"iPhone17,2" → iPhone 16 Pro Max
"iPhone17,3" → iPhone 16
"iPhone17,4" → iPhone 16 Plus

// iPhone 15 series (A17 Pro / A16)
"iPhone15,2" → iPhone 15 Pro (A17 Pro)
"iPhone15,3" → iPhone 15 Pro Max (A17 Pro)
"iPhone15,4" → iPhone 15 Plus (A16)
"iPhone15,5" → iPhone 15 (A16)
"iPhone16,1" → iPhone 15 Pro (alt)
"iPhone16,2" → iPhone 15 Pro Max (alt)

// iPhone 14 series (A16 / A15)
"iPhone14,2" → iPhone 14 Pro (A16)
"iPhone14,3" → iPhone 14 Pro Max (A16)
"iPhone14,4" → iPhone 14 (A15)
"iPhone14,5" → iPhone 14 Plus (A15)

// Older models
"iPhone13,x" → iPhone 13 Pro (A15)
"iPhone12,x" → iPhone 12 Pro (A14)
"iPhone11,x" → iPhone 11 Pro (A13)
```

---

## Capability Matrix

| Device | Chip | TrueDepth | 4K Front | Neural A16+ | Processing | Max Res |
|--------|------|-----------|----------|-------------|------------|---------|
| iPhone 16 Pro | A18 | ✓ | ✓ | ✓ | Real-time | 4K |
| iPhone 16 | A18 | ✓ | ✗ | ✓ | Real-time | 1080p |
| iPhone 15 Pro | A17 Pro | ✓ | ✓ | ✓ | Real-time | 4K |
| iPhone 15 | A16 | ✓ | ✗ | ✓ | Real-time | 1080p |
| iPhone 14 Pro | A16 | ✓ | ✗ | ✓ | Real-time | 1080p |
| iPhone 14 | A15 | ✓ | ✗ | ✗ | Deferred | 1080p |
| iPhone 13 Pro | A15 | ✓ | ✗ | ✗ | Deferred | 1080p |
| iPhone 12 Pro | A14 | ✓ | ✗ | ✗ | Deferred | 1080p |
| iPhone 11 Pro | A13 | ✓ | ✗ | ✗ | Deferred | 720p |

---

## Usage Examples

### 1. Check Device Capabilities

```swift
let capabilities = DeviceCapabilities.current

// Check specific capability
if capabilities.supportsTrueDepth {
    enableFaceMeshOverlay()
}

// Check performance tier
if capabilities.isHighEndDevice {
    enableAllFeatures()
} else if capabilities.isLowEndDevice {
    enableBasicFeaturesOnly()
}
```

### 2. Get Optimized Configuration

```swift
let config = DeviceCapabilities.current.getOptimizedCaptureConfig()

print(config.resolution)              // .fourK or .fullHD or .hd720
print(config.frameRate)                // 60 or 30
print(config.processingMode)           // .realtime or .deferred
print(config.enableFaceMesh)           // true or false
print(config.maxConcurrentFrames)      // 5 or 3
print(config.useHardwareAcceleration)  // true or false
```

### 3. Conditional Feature Display

```swift
// In camera view
if DeviceCapabilities.current.shouldEnableFaceMesh {
    FaceMeshOverlay()
}

// In settings
if DeviceCapabilities.current.shouldShowHighResCaptureToggle {
    Toggle("High-Res Capture (4K)", isOn: $enable4K)
}
```

### 4. Adapt Processing Pipeline

```swift
func processFrame(_ frame: CVPixelBuffer) {
    let capabilities = DeviceCapabilities.current

    if capabilities.shouldUseRealtimePipeline {
        // Use Neural Engine for real-time processing
        processInRealtime(frame)
    } else {
        // Queue for deferred processing
        queueForDeferredProcessing(frame)
    }
}
```

### 5. Display Device Info

```swift
Text("Running on \(DeviceCapabilities.current.deviceName)")
Text("Chip: \(DeviceCapabilities.current.iPhoneModel.chipName)")
```

---

## Graceful Fallbacks

### Older Devices (iPhone 11-13)

**What's Disabled**:
- Real-time processing (uses deferred)
- 4K capture (limited to 1080p or 720p)

**What Still Works**:
- Face detection
- ROI extraction
- Metrics computation
- Analysis (slower but accurate)
- TrueDepth features
- All core functionality

**User Experience**:
- Slightly longer processing times
- Lower resolution (still acceptable quality)
- No "High-Res Capture" toggle shown
- Clear messaging about device optimization

### No TrueDepth (Hypothetical)

If device lacks TrueDepth (unlikely for iPhone X+):
- Face mesh overlay disabled
- Standard face detection still works
- No 3D mesh, but 2D bounds work fine

### Low Battery/Thermal

Future enhancement:
```swift
// Check thermal state
if ProcessInfo.processInfo.thermalState == .critical {
    // Reduce resolution
    // Disable real-time processing
    // Show warning to user
}
```

---

## Integration Points

### Camera Configuration

```swift
class CameraManager {
    let capabilities = DeviceCapabilities.current

    func setupCamera() {
        let config = capabilities.getOptimizedCaptureConfig()

        // Set resolution based on device
        setCameraResolution(config.resolution.dimensions)

        // Set frame rate
        setFrameRate(config.frameRate)

        // Enable/disable features
        if config.enableFaceMesh {
            setupFaceMesh()
        }
    }
}
```

### Processing Pipeline

```swift
class ProcessingManager {
    func processCapture() {
        let capabilities = DeviceCapabilities.current

        if capabilities.shouldUseRealtimePipeline {
            // Process immediately with Neural Engine
            useNeuralEngine = true
            maxConcurrentFrames = capabilities.maxConcurrentFrames
        } else {
            // Queue for background processing
            useNeuralEngine = false
            processInBackground()
        }
    }
}
```

### Settings Persistence

```swift
// Values stored in UserDefaults
@AppStorage("enableHighResCapture") var enableHighRes = false
@AppStorage("enableFaceMesh") var enableFaceMesh = true
@AppStorage("useRealtimeProcessing") var useRealtime = true

// Check capabilities before applying
func applySettings() {
    if enableHighRes && !DeviceCapabilities.current.supports4KVideo {
        // Fallback to 1080p
        enableHighRes = false
    }
}
```

---

## Testing

### Simulator

Simulator is detected and treated as high-end device:
```swift
case .simulator: return true  // Neural Engine
```

**Testing Fallbacks**:
- Modify detection logic to force low-end
- Use physical older devices
- Test on iPhone 11-13 series

### Physical Devices

**High-End** (test all features):
- iPhone 15 Pro / 15 Pro Max
- iPhone 16 series

**Mid-Range** (test fallbacks):
- iPhone 14
- iPhone 15 (non-Pro)

**Low-End** (test aggressive optimization):
- iPhone 11 Pro
- iPhone 12

---

## Debug Output

```swift
print(DeviceCapabilities.current.debugDescription)
```

**Example Output**:
```
Device Capabilities:
- Model: iPhone 15 Pro (iPhone15,2)
- TrueDepth: ✓
- 4K Video: ✓
- Neural Engine A16+: ✓
- Processing Mode: Real-time
- Max Resolution: 4K (3840×2160)
- Frame Rate: 60 fps
- Concurrent Frames: 5
```

---

## Performance Impact

### Memory

- Singleton pattern: One instance, minimal overhead
- Lazy detection: Cached after first call
- No ongoing monitoring

### CPU

- Detection runs once at app launch
- No continuous polling
- Zero runtime cost after initialization

### Battery

- No impact from detection itself
- Settings enable/disable features that affect battery:
  - 4K capture: Higher battery usage
  - Real-time processing: Moderate impact
  - Face mesh: Minimal impact

---

## Future Enhancements

### Potential Additions

1. **Dynamic Adaptation**:
   - Adjust settings based on battery level
   - Reduce quality when thermal throttling
   - Detect background vs foreground state

2. **More Capabilities**:
   - LiDAR sensor detection
   - ProRAW support
   - Cinematic mode availability
   - Display ProMotion (120Hz)

3. **Analytics**:
   - Track which devices use app
   - Identify common capability combinations
   - Optimize for most popular models

4. **User Override**:
   - Advanced settings to force high/low mode
   - Manual resolution selection
   - Performance vs quality slider

---

## Summary

The DeviceCapabilities system provides:

✅ **Automatic Detection**: Identifies iPhone model and chip
✅ **Capability Queries**: TrueDepth, 4K, Neural Engine A16+
✅ **Smart Defaults**: Optimized settings per device
✅ **Graceful Fallbacks**: Older devices still work (slower)
✅ **UI Integration**: Conditional feature display
✅ **User Control**: Settings toggles for capable devices
✅ **Performance**: Zero runtime overhead after init
✅ **Extensible**: Easy to add new capabilities

All features work on all devices, but with appropriate performance expectations!
