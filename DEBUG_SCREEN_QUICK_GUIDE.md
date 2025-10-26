# Debug Screen - Quick Start Guide

## 🎯 What You Got

A professional debug screen with:
- ✅ Live camera preview with overlays
- ✅ Real-time histogram (256 bins)
- ✅ Average luma and blur score displays
- ✅ Exposure/WB lock event tracking
- ✅ Face bounds and landmarks visualization
- ✅ Interactive ROI tap-to-inspect
- ✅ FPS counter and latency measurement
- ✅ Comprehensive performance statistics

---

## 🚀 Access Debug Screen

### From Main Menu

Already integrated! Just:

1. Run the app
2. Tap **"Debug Screen"** in the main menu
3. Camera will start automatically

### From Your Camera View

Add navigation link:

```swift
NavigationLink("Debug") {
    DebugScreen(cameraSession: cameraViewModel.getCameraSession())
}
```

---

## 📱 UI Layout

```
┌─────────────────────────────────────┐
│  Navigation Bar        [Menu ⋯]    │
├─────────────────────────────────────┤
│                                     │
│   CAMERA PREVIEW (300px)            │
│   ┌───────────────────┐  ╔════════╗│
│   │ Face Detection    │  ║ FPS    ║│
│   │   + Landmarks     │  ║ 29.8   ║│
│   │     + ROIs        │  ║ 28ms   ║│
│   └───────────────────┘  ╚════════╝│
│                                     │
├─────────────────────────────────────┤
│  [Metrics] [Events] [Performance]  │
├─────────────────────────────────────┤
│                                     │
│  TAB CONTENT (Scrollable)           │
│                                     │
│  • Histogram                        │
│  • Luma/Blur Cards                  │
│  • Face Info                        │
│  • Event Logs                       │
│  • Stats                            │
│                                     │
└─────────────────────────────────────┘
```

---

## 📊 Tab 1: Metrics

### Live Histogram
- **256 bins** representing luma values
- **Color-coded**: Blue (shadows) → White (midtones) → Yellow (highlights)
- **Clipping indicators**: Red borders on extreme bins
- **Status**: "Histogram Clipped" or "Histogram OK"

### Luma Card
- **Value**: 0.000 - 1.000
- **Status**:
  - < 0.35: "Too Dark" 🟠
  - 0.35-0.65: "Good" 🟢
  - \> 0.65: "Too Bright" 🟠

### Blur Card
- **Value**: 0.0 - 100.0
- **Status**:
  - \> 80: "Sharp" 🟢
  - 60-80: "OK" 🟠
  - < 60: "Blurry" 🔴

### Face Detection Info
- List of detected faces
- Confidence percentages
- Roll, yaw, pitch angles

---

## 📝 Tab 2: Events

### Current Status
- **Exposure**: Locked 🟢 / Unlocked 🟠
- **White Balance**: Locked 🟢 / Unlocked 🟠

### Event Logs
```
🔒 Exposure Locked      2.3 sec ago    14:32:18.456
🔓 Exposure Unlocked    5.1 sec ago    14:32:15.234
☀️ WB Locked           10.8 sec ago   14:32:09.876
```

**Shows**:
- Event type with icon
- Relative time ("2.3 sec ago")
- Absolute timestamp (HH:mm:ss.SSS)
- Last 20 events per type

---

## ⚡ Tab 3: Performance

### Real-Time Metrics

**FPS Card**:
- Current: 29.8 FPS
- Status: Excellent (≥30) / Good (≥24) / Low (<24)
- Color-coded

**Latency Cards**:
- Current latency: 28.3 ms
- Average latency: 31.5 ms
- Benchmarks:
  - < 33ms: 30fps capable 🟢
  - < 50ms: 20fps capable 🟠
  - \> 50ms: High latency 🔴

### Frame Statistics
- Total frames processed
- Faces detected (current frame)
- ROI sets computed

---

## 🎨 Visual Overlays

### Face Bounds
- **Green rectangle** around detected face
- **Confidence label** at top (e.g., "95%")
- Toggle on/off via menu

### Landmarks
- **Cyan**: Left and right eyes
- **Yellow**: Nose
- **Red**: Mouth (outer lips)
- **Green**: Face contour
- Toggle on/off via menu

### ROI Rectangles
- **Pink**: Left/Right cheek
- **Blue**: Forehead (left/center/right)
- **Orange**: Chin (left/center/right)
- **Purple**: Nose
- **Interactive**: Tap to inspect

---

## 🖱️ Interactions

### ROI Tap
1. Tap any ROI rectangle
2. Popup appears with:
   - ROI name (e.g., "Left Cheek")
   - Center coordinates
   - Size (width × height)
   - Area (normalized)
3. Tap outside or X to dismiss

### Toolbar Menu
- **Toggle Face Bounds**: Show/hide green rectangles
- **Toggle Landmarks**: Show/hide facial features
- **Reset Stats**: Clear all statistics (destructive)

---

## 🔧 Integration Points

### 1. Update Blur Score

When you compute blur:

```swift
// In your blur calculation code
let blurScore = computeBlurScore(for: image)

// Update debug view model
await debugViewModel.updateBlurScore(blurScore)
```

### 2. Track White Balance Events

If you implement WB locking:

```swift
func lockWhiteBalance() {
    cameraSession.lockWhiteBalance()
    debugViewModel.addWhiteBalanceLockEvent(isLocked: true)
}

func unlockWhiteBalance() {
    cameraSession.unlockWhiteBalance()
    debugViewModel.addWhiteBalanceLockEvent(isLocked: false)
}
```

### 3. Access Debug from Camera

```swift
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        VStack {
            // Camera UI
        }
        .toolbar {
            ToolbarItem {
                NavigationLink {
                    DebugScreen(cameraSession: viewModel.getCameraSession())
                } label: {
                    Image(systemName: "hammer.fill")
                }
            }
        }
    }
}
```

---

## 🎯 Use Cases

### During Development
✅ Verify face detection is working
✅ Check ROI positioning
✅ Monitor calibration metrics
✅ Ensure proper lighting conditions

### Performance Testing
✅ Benchmark FPS on different devices
✅ Measure processing latency
✅ Identify frame drops
✅ Optimize algorithms

### QA/Testing
✅ Verify exposure lock behavior
✅ Test histogram in various lighting
✅ Validate face detection accuracy
✅ Check ROI coverage

### User Support
✅ Diagnose lighting issues
✅ Verify camera functionality
✅ Check device performance
✅ Document error conditions

---

## 📊 Interpreting Metrics

### Histogram

**Good Histogram**:
- Bell curve centered in midtones
- No clipping in shadows/highlights
- Smooth distribution

**Problematic Histogram**:
- Spikes at extreme bins (clipping)
- Shifted entirely to left (too dark)
- Shifted entirely to right (too bright)

### Luma

**Target Range**: 0.35 - 0.65

- **< 0.35**: Underexposed, increase lighting
- **0.35-0.65**: Optimal for skin analysis
- **> 0.65**: Overexposed, reduce lighting

### FPS

**Target**: ≥ 30 FPS

- **≥ 30**: Smooth, excellent performance
- **24-29**: Acceptable, minor drops
- **< 24**: Poor, investigate bottlenecks

### Latency

**Target**: < 33ms (for 30fps)

- **< 33ms**: Can maintain 30fps
- **33-50ms**: Limited to 20fps
- **> 50ms**: Significant lag, optimize processing

---

## 🐛 Troubleshooting

### No faces detected

**Check**:
- Lighting conditions (luma in range)
- Camera is pointing at face
- Face is within frame
- Face is not too close/far

### Low FPS

**Possible causes**:
- Heavy processing on main thread
- Face detection running synchronously
- Too many overlays rendering
- Device thermal throttling

**Solution**: Check latency tab for bottlenecks

### Histogram clipped

**Shadows clipped** (left side):
- Too dark, increase lighting
- Reduce exposure compensation

**Highlights clipped** (right side):
- Too bright, reduce lighting
- Increase exposure compensation

### High latency

**Check**:
- Number of detected faces (more faces = more processing)
- ROI count (each ROI requires computation)
- Background queue performance

---

## 🎨 Color Reference

### Status Colors
- 🟢 **Green**: Good, locked, optimal
- 🟠 **Orange**: Warning, unlocked, acceptable
- 🔴 **Red**: Error, critical, poor

### Overlay Colors
- **Green**: Face bounds
- **Cyan**: Eye landmarks
- **Yellow**: Nose landmark
- **Red**: Mouth landmark
- **Pink**: Cheek ROIs
- **Blue**: Forehead ROIs
- **Orange**: Chin ROIs
- **Purple**: Nose ROI

---

## 📁 File Reference

```
Tavi/Features/Debug/
├── DebugScreen.swift          # Main UI (600+ lines)
├── DebugViewModel.swift       # State management (300+ lines)
├── HistogramView.swift        # Histogram visualization (150+ lines)
└── DebugOverlayView.swift     # Face/ROI overlays (300+ lines)
```

---

## ✅ Quick Checklist

Before using:
- [ ] Camera permission granted
- [ ] CameraSession initialized
- [ ] Face detection enabled

During use:
- [ ] Check histogram is not clipped
- [ ] Verify luma in 0.35-0.65 range
- [ ] Ensure FPS ≥ 30
- [ ] Confirm latency < 33ms
- [ ] Validate face detection working

For debugging:
- [ ] Toggle overlays to isolate issues
- [ ] Check event log for lock behavior
- [ ] Monitor latency during processing
- [ ] Reset stats to get fresh metrics

---

## 🎉 Summary

The Debug Screen is your **all-in-one tool** for:

1. **Visual Debugging**: See exactly what the camera sees and what's detected
2. **Metric Monitoring**: Real-time feedback on image quality
3. **Performance Analysis**: Identify and fix bottlenecks
4. **Event Tracking**: Complete audit trail of camera state changes

**Already integrated** into ContentView - just tap "Debug Screen" to start!

All features work out of the box with live camera feed. No additional setup required.

Happy debugging! 🛠️
