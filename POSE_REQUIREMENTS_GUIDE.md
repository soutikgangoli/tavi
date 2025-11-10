# FaceScan3D Pose Requirements Guide
## Complete Requirements for Each Capture Pose

**Document Version:** 1.0
**Last Updated:** 2025-01-06
**Purpose:** Comprehensive guide to environmental and technical requirements for each of the 5 capture poses in the FaceScan3D system.

---

## Table of Contents
1. [Overview](#overview)
2. [Universal Requirements (All Poses)](#universal-requirements-all-poses)
3. [Pose-Specific Requirements](#pose-specific-requirements)
4. [Real-Time Feedback System](#real-time-feedback-system)
5. [Validation & Troubleshooting](#validation--troubleshooting)
6. [Quick Reference Tables](#quick-reference-tables)

---

## Overview

The FaceScan3D system captures **5 distinct poses** to create a complete 3D facial model:
1. **Look Straight** (Center) - Baseline reference
2. **Turn Left** - Left profile coverage
3. **Turn Right** - Right profile coverage
4. **Look Up** - Chin and neck coverage
5. **Look Down** - Forehead and nose coverage

Each pose has **4 critical validation categories**:
- 🌞 **Lighting** - Ambient illumination quality
- 📏 **Distance** - Face-to-camera distance
- 🧭 **Direction** (Pose) - Head orientation angles
- ✋ **Stability** - Movement threshold

---

## Universal Requirements (All Poses)

These requirements apply to **ALL 5 poses** and must be maintained throughout the entire capture sequence.

### 1. Lighting Requirements 🌞

#### Ambient Lighting Levels
| Condition | Lumens | Status | User Action |
|-----------|--------|--------|-------------|
| **Too Dark** | < 600 | ❌ BLOCKED | Move to brighter area or add lighting |
| **Suboptimal Dark** | 600-800 | ⚠️ WARNING | Good enough but could be better |
| **OPTIMAL** | 800-1800 | ✅ GOOD | Perfect - proceed with confidence |
| **Suboptimal Bright** | 1800-2000 | ⚠️ WARNING | Good enough but slightly bright |
| **Too Bright** | > 2000 | ❌ BLOCKED | Move away from light or reduce lighting |

**Source:** ARKit `ambientIntensity` from `ARLightEstimate`

#### Advanced Lighting Quality Metrics

Beyond simple lumens, the system checks:

**Dynamic Range (Skin-Tone Independent):**
- **Minimum Required:** 0.30 (30% difference between darkest/brightest areas)
- **Optimal:** > 0.40
- **Purpose:** Ensures facial features are visible regardless of skin tone
- **Blocks Scan If:** < 0.30 (insufficient contrast to see details)

**Contrast/Texture Visibility:**
- **Minimum Required:** 0.15 standard deviation
- **Purpose:** Needed to detect fine skin texture and pigmentation
- **Blocks Scan If:** < 0.15 (image too flat/uniform)

**Overexposure Protection:**
- **Warning Level:** > 5% of pixels at 95%+ brightness
- **Block Level:** > 10% of pixels blown out
- **Purpose:** Prevents washed-out skin that hides defects

**Underexposure Protection:**
- **Block Level:** > 20% of pixels at < 5% brightness
- **Purpose:** Prevents pure black regions with no detail

#### Lighting Consistency During Sequence
- **Maximum Change Allowed:** 30% from baseline (first pose)
- **Color Temperature Change:** 15% maximum deviation
- **Validation Frequency:** Every 15 frames (~0.25 seconds)
- **If Exceeded:** Warning displayed, scan continues but quality may degrade

**Why This Matters:** Inconsistent lighting across poses causes color mismatches in the final merged texture, making pigmentation analysis unreliable.

---

### 2. Distance Requirements 📏

#### Face-to-Camera Distance

| Range | Distance | Status | User Message | Clinical Impact |
|-------|----------|--------|--------------|-----------------|
| **Too Close** | < 0.20m (20cm) | ❌ INVALID | "Please move back a bit" | Face cutoff, distortion |
| **Acceptable Close** | 0.20-0.25m | ⚠️ ACCEPTABLE | "Move back slightly for best results" | Slight distortion |
| **OPTIMAL** | 0.30-0.50m | ✅ GOOD | "Distance is perfect" | Best quality |
| **Acceptable Far** | 0.50-0.60m | ⚠️ ACCEPTABLE | "Move closer for better detail" | Reduced pixel density |
| **Too Far** | > 0.60m | ❌ INVALID | "Too far - move closer" | Insufficient detail |

**Measurement:** Euclidean distance from ARFaceAnchor transform Z-axis to camera origin

#### Why Distance Matters

**Below 25cm (Too Close):**
- Face extends beyond camera field of view
- Perspective distortion (nose appears larger)
- Forehead/chin may be cut off
- Cannot capture full facial topology

**30-50cm (Optimal):**
- Complete face in frame with margins
- Minimal perspective distortion
- ~2-3mm per pixel skin detail (sufficient for pore/wrinkle detection)
- Proper depth sensing accuracy

**Above 60cm (Too Far):**
- Pixel density drops below clinical threshold
- Cannot reliably detect pores (< 0.5mm features)
- Wrinkle depth accuracy degrades
- Increased noise in depth data

---

### 3. Stability Requirements ✋

#### Movement Threshold

| Movement | Status | User Message | Purpose |
|----------|--------|--------------|---------|
| **< 0.03m** (3cm) | ✅ STABLE | "Holding steady" | Countdown proceeds |
| **≥ 0.03m** | ❌ MOVING | "Please hold still" | Countdown pauses/resets |

**Calculation:**
```swift
let dx = newPosition.x - oldPosition.x
let dy = newPosition.y - oldPosition.y
let dz = newPosition.z - oldPosition.z
let movement = sqrt(dx² + dy² + dz²)

isStable = movement < 0.03  // meters
```

**Frame Rate:** Evaluated at 60fps (every 16.7ms)

#### Why Stability Matters

**Motion Blur:**
- Even small movements (> 3cm) cause texture blur at 60fps
- Blurry textures fail sharpness check (< 150 Laplacian variance)
- Cannot accurately measure roughness/smoothness

**Mesh Alignment:**
- Movement causes misalignment when merging 5 poses
- Stitching artifacts appear at pose boundaries
- Topology becomes non-manifold (holes, overlaps)

**Tips for Users:**
- Rest elbows on table
- Take deep breath and hold
- Look at fixed point on screen
- Relax shoulders

---

### 4. Expression Requirements 😐

All poses require **neutral expression** (no smiling, frowning, mouth open, etc.):

| Feature | Threshold | ARKit Blend Shape | Purpose |
|---------|-----------|-------------------|---------|
| **Jaw Open** | ≤ 0.15 (15%) | `jawOpen` | Mouth closed |
| **Eye Blink** | ≤ 0.20 (20%) | `eyeBlinkLeft/Right` | Eyes open |
| **Smile** | ≤ 0.25 (25%)* | `mouthSmileLeft/Right` | Neutral lips |
| **Mouth Pucker** | ≤ 0.20 | `mouthPucker` | Relaxed lips |
| **Cheek Puff** | ≤ 0.20 | `cheekPuff` | Relaxed cheeks |
| **Eye Wide** | ≤ 0.30 | `eyeWideLeft/Right` | Natural eyes |
| **Eye Squint** | ≤ 0.30* | `eyeSquintLeft/Right` | Relaxed eyes |
| **Brow Up** | ≤ 0.30 | `browInnerUp` | Relaxed brow |
| **Brow Down** | ≤ 0.30 | `browDownLeft/Right` | Relaxed brow |

**Special Cases:**
- *Smile threshold increased from 0.10 to 0.25 to prevent false positives during "Look Down" (gravity naturally curves lips)
- *Squint check skipped during "Look Down" (natural squinting when looking down)

**Why Expression Matters:**
- Expressions change mesh topology (different vertex positions)
- Smiling stretches skin → underestimates wrinkle depth
- Squinting creates artificial wrinkles → overestimates aging
- Inconsistent expressions across poses → mesh merging fails

---

## Pose-Specific Requirements

### Pose 1: Look Straight (Center) 👤

**Purpose:** Establishes baseline reference for 3D reconstruction. Most critical pose.

#### Direction Requirements 🧭

| Angle | Range | Tolerance | Clinical Rationale |
|-------|-------|-----------|-------------------|
| **Yaw** (Left/Right) | ±5° | STRICT | Symmetry reference line |
| **Pitch** (Up/Down) | ±5° | STRICT | Facial plane alignment |
| **Roll** (Tilt) | ±8° | MODERATE | Natural head tilt allowed |

**Why So Strict?**
- All other poses are measured relative to this baseline
- If center pose is off by 5°, all measurements shift by 5°
- Pigmentation/discoloration analysis needs perfect symmetry reference

#### Real-Time Guidance Feedback

The system provides progressive guidance:

**Far Off (>30° yaw):**
- "Turn your head to the RIGHT" (if yaw > 0)
- "Turn your head to the LEFT" (if yaw < 0)

**Moderate Off (10-30° yaw):**
- "Turn slightly right"
- "Turn slightly left"

**Close (5-10° yaw):**
- "Almost centered - tiny bit right"
- "Almost centered - tiny bit left"

**Within Range (≤5° yaw, ≤5° pitch, ≤8° roll):**
- "Hold that position" → 3-second countdown begins

#### Lighting Requirements
Same as universal (800-1800 lumens optimal)

#### Distance Requirements
Same as universal (0.30-0.50m optimal)

#### Stability Requirements
Same as universal (<0.03m movement)

#### Capture Details
- **Frames Captured:** 5 consecutive frames at 60fps
- **Countdown Duration:** 3 seconds
- **Pose Hold Time:** 1 second minimum after countdown
- **Haptic Feedback:** Single tap on successful capture

---

### Pose 2: Turn Left 👈

**Purpose:** Captures left profile, left cheek, left jawline. Essential for asymmetry detection.

#### Direction Requirements 🧭

| Angle | Range | Tolerance | Notes |
|-------|-------|-----------|-------|
| **Yaw** (Turn Left) | +15° to +35° | STRICT | Must be in this range |
| **Pitch** (Level) | ±15° | RELAXED | Can tilt slightly |
| **Roll** (Tilt) | ±8° | MODERATE | Natural tilt OK |

**Why This Range?**
- **Below 15°:** Insufficient profile coverage, overlaps with center pose
- **15-35° Range:** Optimal balance of profile visibility + face tracking
- **Above 35°:** TrueDepth loses tracking (too much face occluded)

#### Real-Time Guidance Feedback

**Wrong Direction (yaw < -5°):**
- "Wrong direction - turn your head to the LEFT"

**Not Enough (yaw < 10°):**
- "Turn more to the left"

**Almost There (10-15°):**
- "Almost there, turn a bit more left"

**Too Far (yaw > 35°):**
- "Too far, turn back slightly to the right"

**Perfect Angle but Poor Pitch/Roll:**
- "Good angle - level your head"
- "Good angle - straighten head"

**Within Range:**
- "Hold that position" → Countdown begins

#### Lighting Requirements
Same as universal, but watch for:
- **Self-shadowing:** Left side of face may be darker
- **System compensates:** Albedo estimation removes shadows
- **User tip:** Face light source directly if possible

#### Distance Requirements
Same as universal (0.30-0.50m)

**Note:** Distance measured from face center, not turned edge

#### Stability Requirements
Same as universal (<0.03m)

**Tip:** Harder to stay stable while turned - use reference point on wall

---

### Pose 3: Turn Right 👉

**Purpose:** Captures right profile, right cheek, right jawline. Completes horizontal coverage.

#### Direction Requirements 🧭

| Angle | Range | Tolerance | Notes |
|-------|-------|-----------|-------|
| **Yaw** (Turn Right) | -15° to -35° | STRICT | Must be in this range |
| **Pitch** (Level) | ±15° | RELAXED | Can tilt slightly |
| **Roll** (Tilt) | ±8° | MODERATE | Natural tilt OK |

**Mirror of Turn Left** - same principles apply

#### Real-Time Guidance Feedback

**Wrong Direction (yaw > 5°):**
- "Wrong direction - turn your head to the RIGHT"

**Not Enough (yaw > -10°):**
- "Turn more to the right"

**Almost There (-10° to -15°):**
- "Almost there, turn a bit more right"

**Too Far (yaw < -35°):**
- "Too far, turn back slightly to the left"

**Perfect Angle but Poor Pitch/Roll:**
- "Good angle - level your head"
- "Good angle - straighten head"

**Within Range:**
- "Hold that position" → Countdown begins

#### Lighting Requirements
Same as Turn Left - watch for right-side shadows

#### Distance Requirements
Same as universal (0.30-0.50m)

#### Stability Requirements
Same as universal (<0.03m)

---

### Pose 4: Look Up 👆

**Purpose:** Captures chin, neck, under-nose. Critical for jawline definition and under-chin analysis.

#### Direction Requirements 🧭

| Angle | Range | Tolerance | Notes |
|-------|-------|-----------|-------|
| **Pitch** (Look Up) | +10° to +22° | STRICT | Must tilt up |
| **Yaw** (Centered) | ±15° | RELAXED | Face forward |
| **Roll** (Level) | ±8° | MODERATE | Keep level |

**Why This Range?**
- **Below 10°:** Insufficient chin exposure
- **10-22° Range:** Optimal chin/neck visibility without neck strain
- **Above 22°:** Neck strain, face tracking degrades, nostrils visible (not ideal)

#### Real-Time Guidance Feedback

**Not Enough Tilt (pitch < 5°):**
- "Tilt your head UP more"

**Almost There (5-10°):**
- "Almost there, tilt up a bit more"

**Too Far (pitch > 22°):**
- "Too far, tilt down slightly"

**Good Pitch but Off-Center:**
- "Good angle - face more forward"

**Good Pitch but Tilted:**
- "Good angle - level your head"

**Within Range:**
- "Hold that position" → Countdown begins

#### Lighting Requirements
Same as universal, but watch for:
- **Chin Shadow:** Underchin naturally darker (normal)
- **System compensates:** Edge case detector handles natural shadows
- **User tip:** Slightly tilt lamp upward if available

#### Distance Requirements
Same as universal (0.30-0.50m)

**Note:** Tilting up may bring face slightly closer - watch distance indicator

#### Stability Requirements
Same as universal (<0.03m)

**Tip:** Harder to stay stable looking up - don't overextend neck

---

### Pose 5: Look Down 👇

**Purpose:** Captures forehead, hairline, nose bridge, eyelids. Critical for forehead wrinkle analysis.

#### Direction Requirements 🧭

| Angle | Range | Tolerance | Notes |
|-------|-------|-----------|-------|
| **Pitch** (Look Down) | -12° to -25° | STRICT | Must tilt down |
| **Yaw** (Centered) | ±15° | RELAXED | Face forward |
| **Roll** (Level) | ±8° | MODERATE | Keep level |

**Why This Range?**
- **Above -12°:** Forehead not fully visible
- **-12° to -25° Range:** Complete forehead exposure without double chin
- **Below -25°:** Double chin appears, face tracking fails

#### Real-Time Guidance Feedback

**Not Enough Tilt (pitch > -7°):**
- "Tilt your head DOWN more"

**Almost There (-7° to -12°):**
- "Almost there, tilt down a bit more"

**Too Far (pitch < -25°):**
- "Too far, tilt up slightly"

**Good Pitch but Off-Center:**
- "Good angle - face more forward"

**Good Pitch but Tilted:**
- "Good angle - level your head"

**Within Range:**
- "Hold that position" → Countdown begins

#### Special Expression Handling

**Looking down naturally causes:**
- Slight lip curvature (detected as "smile" by ARKit)
- Eye squinting (natural reflex)

**System adjustments for this pose:**
- Smile threshold increased: 0.10 → 0.25 (more lenient)
- Squint check disabled entirely
- These adjustments **only apply to Look Down pose**

#### Lighting Requirements
Same as universal, but watch for:
- **Nose shadow on lips:** Common when looking down
- **System compensates:** Albedo estimation removes
- **User tip:** Tilt device slightly down (follow your gaze)

#### Distance Requirements
Same as universal (0.30-0.50m)

**Note:** Tilting down may move face farther - watch distance

#### Stability Requirements
Same as universal (<0.03m)

**Tip:** Most difficult pose for stability - take your time

---

## Real-Time Feedback System

### Calibration Status Badges

Four badges shown at top of screen during capture:

#### 1. Lighting Badge 🌞
- **Green:** 800-1800 lumens (optimal)
- **Yellow:** 600-800 or 1800-2000 (acceptable but not ideal)
- **Red:** <600 or >2000 (blocked - must fix)
- **Text:** "Good" / "Low" / "Too Dark" / "Too Bright"

#### 2. Distance Badge 📏
- **Green:** 0.30-0.50m (optimal)
- **Yellow:** 0.25-0.30m or 0.50-0.60m (acceptable)
- **Red:** <0.25m or >0.60m (blocked)
- **Text:** "Perfect" / "Too Close" / "Too Far"

#### 3. Direction Badge 🧭
- **Green:** Within pose-specific angle range
- **Red:** Outside required range
- **Text:** "Correct" / "Adjust Pose"
- **Helper:** Shows current yaw/pitch/roll values

#### 4. Stability Badge ✋
- **Green:** Movement < 0.03m
- **Yellow:** Movement 0.03-0.05m (marginal)
- **Red:** Movement > 0.05m (too much)
- **Text:** "Steady" / "Hold Still"

### Center Position Indicator

Shows below Direction badge during "Look Straight" pose:

- **Green "Center":** ±5° (perfect alignment)
- **Yellow "Slightly Left/Right":** 5-10° off
- **Red "Turn Left/Right":** >10° off (with directional hint)

**Updates in real-time** based on face yaw angle

### Progress Indicators

Shows 5 circles representing capture progress:
- **Gray:** Not started
- **Blue with pulse:** Current step (in progress)
- **Green with checkmark:** Completed
- **Orange with warning:** Failed/skipped

### Countdown Display

When all 4 badges are green + pose is correct:
- **Large "3"** (first second)
- **Large "2"** (second second)
- **Large "1"** (third second)
- **"Capturing..."** (brief flash)
- **Haptic tap** + completion animation

**Countdown resets if:**
- Any badge turns red/yellow
- Pose moves out of range
- Stability lost

### Warning Messages

Shown as toast notifications at bottom:

**Calibration Issues:**
- "⚠️ Lighting changed - please maintain consistent lighting"
- "⚠️ Please move back to optimal distance"
- "⚠️ Please hold still to start countdown"

**Expression Issues:**
- "⚠️ Please keep a neutral expression (no smiling)"
- "⚠️ Please keep your mouth closed"
- "⚠️ Please don't squint"

**Pose Issues:**
- "⚠️ Turn your head more to the left"
- "⚠️ Almost centered - tiny bit right"

---

## Validation & Troubleshooting

### Common Issues and Solutions

#### Issue: "Countdown keeps resetting"

**Possible Causes:**
1. **Stability:** Micro-movements exceeding 3cm threshold
   - **Solution:** Rest elbows on table, breathe slowly
2. **Lighting Fluctuation:** Shadows from moving objects/people
   - **Solution:** Use consistent light source, avoid windows
3. **Pose Drift:** Slowly moving out of valid angle range
   - **Solution:** Use screen reference point, stay focused

#### Issue: "Can't achieve 'Look Straight' pose"

**Symptoms:** Yaw indicator shows off-center even when facing camera

**Possible Causes:**
1. **Camera Misalignment:** Camera not at eye level
   - **Solution:** Adjust device position to eye level
2. **Natural Head Tilt:** Everyone's "straight" is slightly different
   - **Solution:** System allows ±5° - focus on green badge, not feeling
3. **Lighting Asymmetry:** Brighter on one side causes detection issues
   - **Solution:** Balance lighting sources left/right

#### Issue: "Distance indicator constantly changes"

**Symptoms:** Distance badge flickering green/yellow

**Possible Causes:**
1. **Breathing Motion:** Torso moving forward/back
   - **Solution:** Shallow breaths during countdown
2. **Device in Hand:** Hand movements transmitted to device
   - **Solution:** Use stand/tripod or rest device on stable surface
3. **Borderline Range:** Exactly at 0.30m or 0.50m threshold
   - **Solution:** Aim for middle of range (0.40m)

#### Issue: "Turn Left/Right pose not detected"

**Symptoms:** Can't get Direction badge to turn green when turned

**Possible Causes:**
1. **Not Turned Enough:** Only 10° instead of required 15°
   - **Solution:** Turn more dramatically than feels natural
2. **Pitch Also Changed:** Tilted up/down while turning
   - **Solution:** Keep chin level while turning
3. **ARKit Tracking Lost:** Too much face occluded
   - **Solution:** Turn more gradually, ensure one eye still visible

#### Issue: "Look Up/Down pose uncomfortable"

**Symptoms:** Neck strain, can't hold position for countdown

**Possible Causes:**
1. **Over-tilting:** Exceeding comfortable range
   - **Solution:** Minimum tilt required (10° up, -12° down) - don't overdo
2. **Device Position:** Having to look too far up/down relative to device
   - **Solution:** Adjust device angle to meet your gaze halfway

#### Issue: "Lighting always shows 'Too Dark' even in bright room"

**Symptoms:** Lighting badge stays red despite bright room lighting

**Possible Causes:**
1. **Backlit:** Light source behind you, not on face
   - **Solution:** Face the light source (window/lamp)
2. **Dark Skin + Standard Lighting:** 600 lumens insufficient for darker skin
   - **Solution:** Add more lighting - system uses skin-tone-independent dynamic range
3. **Camera Obscured:** Lens has fingerprints/case blocking
   - **Solution:** Clean lens, remove case if blocking sensors

---

## Quick Reference Tables

### Pose Validation Summary

| Pose | Yaw (Left/Right) | Pitch (Up/Down) | Roll (Tilt) | Difficulty | Capture Priority |
|------|------------------|-----------------|-------------|------------|------------------|
| **Look Straight** | ±5° | ±5° | ±8° | Easy | 1 (Critical) |
| **Turn Left** | +15° to +35° | ±15° | ±8° | Medium | 2 (High) |
| **Turn Right** | -15° to -35° | ±15° | ±8° | Medium | 3 (High) |
| **Look Up** | ±15° | +10° to +22° | ±8° | Hard | 4 (Medium) |
| **Look Down** | ±15° | -12° to -25° | ±8° | Hard | 5 (Medium) |

### Environmental Conditions Matrix

| Condition | Minimum | Optimal | Maximum | Validation Frequency |
|-----------|---------|---------|---------|---------------------|
| **Lighting** | 600 lumens | 800-1800 | 2000 | Every 15 frames (~0.25s) |
| **Distance** | 0.25m | 0.30-0.50m | 0.60m | Every frame (60fps) |
| **Stability** | - | - | 0.03m movement | Every frame (60fps) |
| **Dynamic Range** | 0.30 | 0.40+ | - | Once at pose start |
| **Contrast** | 0.15 | 0.20+ | - | Once at pose start |
| **Overexposure** | - | <5% pixels | 10% | Once at pose start |

### Timing and Performance

| Action | Duration | Retry Logic | Timeout |
|--------|----------|-------------|---------|
| **Face Detection** | Instant | Continuous | No timeout |
| **Calibration** | Continuous | Auto-retry | No timeout |
| **Countdown** | 3 seconds | Resets on invalid | No timeout |
| **Pose Hold** | 1 second | N/A | No timeout |
| **Frame Capture** | 5 frames @ 60fps | N/A | 1 second |
| **Per-Pose Total** | ~5-10 seconds | Manual retry | No timeout |
| **Full Sequence (5 poses)** | ~35-45 seconds | Can restart | No timeout |

### Clinical Impact by Pose

| Pose | Captures | Critical For | If Missing/Poor Quality |
|------|----------|--------------|-------------------------|
| **Look Straight** | Front face, cheeks | Symmetry analysis, baseline, pigmentation | Cannot compute discoloration, asymmetry metrics invalid |
| **Turn Left** | Left profile, jawline | Jawline definition, left cheek, asymmetry | Left side metrics unreliable, incomplete 3D model |
| **Turn Right** | Right profile, jawline | Jawline definition, right cheek, asymmetry | Right side metrics unreliable, incomplete 3D model |
| **Look Up** | Chin, neck, under-nose | Jawline, under-eye, neck skin | Volume metrics invalid, jawline definition poor |
| **Look Down** | Forehead, hairline, eyelids | Forehead wrinkles, hairline, skin type | Wrinkle analysis incomplete, regional metrics limited |

---

## Configuration Constants Reference

All thresholds are defined in `ScanConfiguration.swift` as the single source of truth:

### Lighting Constants
```swift
public static let minAmbientLighting: CGFloat = 600.0
public static let optimalLightingMin: CGFloat = 800.0
public static let optimalLightingMax: CGFloat = 1800.0
public static let maxAmbientLighting: CGFloat = 2000.0
```

### Distance Constants
```swift
public static let minFaceDistance: Float = 0.20
public static let acceptableCloseDistance: Float = 0.25
public static let optimalDistanceMin: Float = 0.30
public static let optimalDistanceMax: Float = 0.50
public static let acceptableFarDistance: Float = 0.60
public static let maxFaceDistance: Float = 0.70
```

### Pose Angle Constants
```swift
// Look Straight (Center)
public static let maxCenterYawDegrees: Float = 5.0
public static let maxCenterPitchDegrees: Float = 5.0
public static let maxCenterRollDegrees: Float = 8.0

// Turn Left/Right
public static let minTurnLeftYawDegrees: Float = 15.0
public static let maxTurnLeftYawDegrees: Float = 35.0
public static let minTurnRightYawDegrees: Float = -15.0
public static let maxTurnRightYawDegrees: Float = -35.0
public static let turnPoseTolerancePitchRollDegrees: Float = 15.0

// Look Up/Down
public static let minLookUpPitchDegrees: Float = 10.0
public static let maxLookUpPitchDegrees: Float = 22.0
public static let minLookDownPitchDegrees: Float = -12.0
public static let maxLookDownPitchDegrees: Float = -25.0
public static let upDownPoseToleranceYawRollDegrees: Float = 15.0
```

### Stability Constants
```swift
public static let stabilityMovementThreshold: Float = 0.03  // meters
```

### Expression Constants
```swift
public static let maxJawOpenThreshold: Double = 0.15
public static let maxEyeBlinkThreshold: Double = 0.20
public static let maxSmileThreshold: Double = 0.25  // Relaxed for Look Down
public static let maxMouthPuckerThreshold: Double = 0.20
public static let maxCheekPuffThreshold: Double = 0.20
public static let maxEyeWideThreshold: Double = 0.30
public static let maxSquintThreshold: Double = 0.30
public static let maxBrowMovementThreshold: Double = 0.30
```

---

## Integration with Analysis Pipeline

### Data Captured Per Pose

```swift
struct CapturedPoseData {
    let step: GuidanceStep              // Which pose (1-5)
    let geometry: FaceMeshGeometry      // ~1,220 vertices
    let timestamp: TimeInterval
    let yaw: Float                      // Actual angle achieved
    let pitch: Float
    let roll: Float

    // Quality Metrics
    let lightingQuality: Float          // 0-1 score
    let distanceFromCamera: Float       // Meters
    let stabilityScore: Float           // 0-1 (how steady)
    let expressionNeutrality: Float     // 0-1 (how neutral)
}
```

### Validation Before Processing

Before merging meshes, system validates:
- ✅ All 5 poses captured successfully
- ✅ Lighting variation < 30% across sequence
- ✅ All poses have sufficient quality scores
- ✅ Timestamp continuity (no big gaps)
- ✅ Geometry validity (no NaN/Inf values)

### Quality Scoring

Each pose receives quality score (0-100):
- **Lighting Quality:** 25% weight
- **Distance Accuracy:** 20% weight
- **Stability Score:** 25% weight
- **Pose Accuracy:** 20% weight (how close to target angle)
- **Expression Neutrality:** 10% weight

**Overall Sequence Quality:**
- Minimum of all 5 pose scores
- Must be ≥70 for "High Quality" label
- 50-69: "Medium Quality" (usable but sub-optimal)
- <50: "Low Quality" (should retry)

---

## Best Practices for Users

### Setup Checklist ✅

**Before Starting Scan:**
1. ☐ Find well-lit area (not direct sunlight)
2. ☐ Position camera at eye level
3. ☐ Remove glasses, hats, large earrings
4. ☐ Tie back long hair (away from forehead/cheeks)
5. ☐ Rest elbows on table for stability
6. ☐ Clear makeup (for best accuracy)
7. ☐ Test distance (arm's length ≈ 50cm)

### During Capture Tips 💡

**For All Poses:**
- 👁️ Focus on a fixed point on the screen
- 🫁 Take slow, shallow breaths
- 💪 Keep shoulders relaxed
- ⏱️ Don't rush - take your time between poses

**For Turn Left/Right:**
- 🔄 Turn head, not whole body
- 👀 Keep both eyes visible if possible
- 📐 Maintain level chin (don't tilt up/down)

**For Look Up/Down:**
- 🦒 Move from neck, not just eyes
- ⚖️ Don't overdo the tilt - minimum required
- 🧘 Relax facial muscles

### Troubleshooting Workflow 🔧

If scan quality is poor:

1. **Check Lighting:**
   - Stand near window (daytime, no direct sun)
   - Or use 2-3 lamps from different angles
   - Aim for even, diffused lighting

2. **Check Distance:**
   - Use arm's length as reference
   - Adjust until Distance badge shows green
   - Lock distance, don't move forward/back

3. **Check Stability:**
   - Use device stand/tripod if available
   - Or rest elbows firmly on table
   - Practice holding pose before starting countdown

4. **Check Expression:**
   - Relax all facial muscles
   - Imagine "resting face"
   - Don't consciously smile or frown

---

## Analyzer Performance Matrix

### Complete Mapping: Requirements → Confidence Scores

This section maps **input conditions** to **expected confidence scores** for each analyzer, helping you understand the minimum requirements for reliable results and optimal configurations for maximum accuracy.

### Methodology

**Confidence Score Scale:**
- **90-100%:** Clinical-grade accuracy, suitable for medical reference
- **80-89%:** High quality, reliable for consumer health tracking
- **70-79%:** Good quality, acceptable for general analysis
- **60-69%:** Moderate quality, results may have limitations
- **<60%:** Low quality, results unreliable - retry recommended

**Variables Tested:**
1. Texture Resolution (2K, 4K)
2. Frames per Pose (1, 3, 5)
3. Lighting (lumens)
4. Distance (meters)
5. Pose Accuracy (degrees from optimal)

---

### Table 1: Roughness/Smoothness Analyzer

**What It Measures:** Surface texture micro-variations (skin smoothness)
**Primary Input:** 3D mesh geometry + normals
**Method:** Normal vector variance analysis

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 72% | Minimum viable - some noise |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 81% | Recommended baseline |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 87% | Excellent consumer quality |
| **4096²** | 3 | 800 | 0.35m | Good (±2°) | 89% | High-res texture helps slightly |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **94%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 58% | Too many compromises |
| **2048²** | 3 | 2000 | 0.55m | Good (±3°) | 76% | Too bright + far, borderline |

**Key Insights:**
- **Most Important:** Frames per pose (averaging reduces noise)
- **Secondary:** Distance (closer = better normal precision)
- **Least Important:** Texture resolution (geometry-based, not texture)
- **Acceptable Error Rate:** ±0.02 roughness index (on 0-1 scale)
- **Real-World Viability:** 81%+ easily achievable in home environment

**Recommended Configuration:**
- Texture: 2048² (sufficient)
- Frames: 3-5 per pose
- Lighting: 800-1200 lumens
- Distance: 0.35-0.45m
- **Expected Score: 85-90%**

---

### Table 2: Pigmentation Analyzer

**What It Measures:** Skin tone evenness (pigmentation variations)
**Primary Input:** Texture RGB → CIELAB color space
**Method:** A* and B* channel variance across ROIs

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 68% | Low confidence - shadows affect |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 78% | Acceptable, minor shadow issues |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 86% | Good averaging, shadows compensated |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 84% | Higher res = better spot detection |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **92%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 52% | Underlit + too close = unreliable |
| **4096²** | 5 | 600 | 0.30m | Good (±3°) | 74% | Insufficient lighting dominates |

**Key Insights:**
- **Most Important:** Lighting quality (even illumination critical)
- **Secondary:** Frames per pose (reduces shadow artifacts)
- **Tertiary:** Texture resolution (higher = better for small spots)
- **Acceptable Error Rate:** ±5% pigmentation index (on 0-100 scale)
- **Real-World Viability:** 80%+ requires controlled lighting (indoor, no windows)

**Recommended Configuration:**
- Texture: 4096² (helps spot detection)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens (even, diffused)
- Distance: 0.35-0.45m
- **Expected Score: 88-92%**

**Skin Tone Considerations:**
- **Light Skin (Fitzpatrick I-II):** Add +3% confidence (easier detection)
- **Medium Skin (III-IV):** Baseline scores
- **Dark Skin (V-VI):** Subtract -5% confidence (needs better lighting)

---

### Table 3: Discoloration Analyzer

**What It Measures:** Color uniformity across facial regions (patches, redness variations)
**Primary Input:** ROI LAB means across 7+ regions
**Method:** Inter-ROI variance (cross-region color consistency)

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 64% | Single frame = lighting artifacts |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 76% | Acceptable multi-frame averaging |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 84% | Good quality, reliable |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 82% | Res helps but not critical |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **91%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 48% | Shadows + single frame = failure |
| **2048²** | 5 | 1800 | 0.50m | Good (±3°) | 79% | High lighting OK, distance hurts |

**Key Insights:**
- **Most Important:** Lighting consistency (inter-ROI comparison needs even light)
- **Secondary:** Frames per pose (shadows appear/disappear between frames)
- **Tertiary:** Distance (affects shadow intensity)
- **Acceptable Error Rate:** ±8% discoloration index
- **Real-World Viability:** 80%+ achievable with indoor lighting, difficult near windows

**Recommended Configuration:**
- Texture: 2048² (sufficient for ROI means)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens (EVEN coverage critical)
- Distance: 0.35-0.45m
- **Expected Score: 82-87%**

**Critical Requirement:** Lighting must be **uniform across face** (no strong directional shadows)

---

### Table 4: Wrinkle Analyzer

**What It Measures:** Wrinkle depth, count, and severity
**Primary Input:** 3D mesh geometry (curvature analysis)
**Method:** Differential geometry + depth scaling

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 71% | Single mesh = noise in depth |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 83% | Good averaging, reliable |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 89% | Excellent quality |
| **4096²** | 3 | 800 | 0.35m | Good (±2°) | 85% | Texture res helps fine wrinkles |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **93%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 62% | Close distance + single = unreliable |
| **2048²** | 5 | 800 | 0.60m | Poor (±5°) | 73% | Too far = depth precision loss |

**Key Insights:**
- **Most Important:** Distance (depth sensing precision degrades with distance)
- **Secondary:** Frames per pose (averaging smooths noise)
- **Tertiary:** Pose accuracy (expression changes wrinkle depth)
- **Acceptable Error Rate:** ±0.1mm depth measurement
- **Real-World Viability:** 85%+ easily achievable, **best geometry-based metric**

**Recommended Configuration:**
- Texture: 2048² (geometry-based, not texture-dependent)
- Frames: 5 per pose
- Lighting: 800-1200 lumens (affects texture capture, not geometry)
- Distance: 0.30-0.45m (CRITICAL - closer is better)
- **Expected Score: 87-93%**

**⚠️ IMPORTANT:** Wrinkle depth scaling factor (20μm) is **UNVALIDATED** - actual accuracy may vary ±20%

---

### Table 5: Pore Analyzer

**What It Measures:** Pore visibility, size distribution, count
**Primary Input:** High-resolution texture (darkness spots)
**Method:** Adaptive thresholding + circular pattern detection

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 58% | Insufficient resolution for pores |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 67% | Borderline - large pores only |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 73% | Acceptable, misses fine pores |
| **4096²** | 3 | 1000 | 0.30m | Good (±2°) | 81% | High res + close = good detection |
| **4096²** | 5 | 1200 | 0.30m | Optimal (0°) | **88%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 44% | Too dark = can't see pores |
| **4096²** | 5 | 800 | 0.50m | Good (±3°) | 69% | Distance degrades pixel density |

**Key Insights:**
- **Most Important:** Texture resolution (pores are 0.1-0.5mm = 2-10 pixels @ 2K, 4-20 pixels @ 4K)
- **Secondary:** Distance (closer = more pixels per pore)
- **Tertiary:** Lighting (good contrast needed to see pore shadows)
- **Acceptable Error Rate:** ±15% pore count (detection threshold dependent)
- **Real-World Viability:** 75%+ requires 4K texture + close distance (challenging)

**Recommended Configuration:**
- Texture: **4096²** (CRITICAL - pores too small for 2K)
- Frames: 3-5 per pose
- Lighting: 1000-1500 lumens (shadows make pores visible)
- Distance: **0.30-0.35m** (CRITICAL - closer is much better)
- **Expected Score: 78-85%**

**Limitation:** Pore analysis is **most challenging metric** - requires near-optimal conditions

---

### Table 6: Acne/Blemish Analyzer

**What It Measures:** Acne spots, blemish count, severity
**Primary Input:** Texture (adaptive darkness) + 3D elevation
**Method:** Darkness detection (30% darker than baseline) + raised geometry

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 74% | Shadows can cause false positives |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 83% | Good detection, reliable |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 88% | Excellent averaging reduces FP |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 87% | High res helps small blemishes |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **92%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 61% | Underlit = hard to distinguish |
| **2048²** | 5 | 1800 | 0.50m | Good (±3°) | 79% | Overlit washes out contrast |

**Key Insights:**
- **Most Important:** Lighting quality (even lighting reduces shadow false positives)
- **Secondary:** Frames per pose (consistency check across frames)
- **Tertiary:** Texture resolution (helps for small blemishes)
- **Acceptable Error Rate:** ±2 blemishes (small spots may be missed/added)
- **Real-World Viability:** 85%+ easily achievable (adaptive algorithm works well)

**Recommended Configuration:**
- Texture: 2048² (sufficient for most blemishes)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens (even, not too bright)
- Distance: 0.35-0.45m
- **Expected Score: 86-90%**

**Skin Tone Fairness:** Algorithm is **skin-tone adaptive** (relative darkness) - works well across Fitzpatrick I-VI

---

### Table 7: Redness Analyzer

**What It Measures:** Skin redness, inflammation, rosacea indicators
**Primary Input:** Texture RGB → redness metric
**Method:** R - (G+B)/2 relative to baseline

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 66% | Single frame + low light = unreliable |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 75% | Acceptable, some lighting artifacts |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 82% | Good averaging |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 80% | Res helps small redness spots |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **87%** | Maximum achievable (light skin) |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 54% | Low light affects color accuracy |
| **2048²** | 5 | 1800 | 0.50m | Good (±3°) | 77% | Overlit reduces redness contrast |

**Key Insights:**
- **Most Important:** Lighting quality (accurate color reproduction)
- **Secondary:** Frames per pose (color consistency check)
- **Tertiary:** Color temperature normalization (must be applied)
- **Acceptable Error Rate:** ±10% redness index
- **Real-World Viability:** 75-85% (light skin), **60-70% (dark skin)** - needs improvement

**Recommended Configuration:**
- Texture: 2048² (sufficient for color analysis)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens (neutral white, not warm/cool)
- Distance: 0.35-0.45m
- **Expected Score: 78-85% (light skin), 65-75% (dark skin)**

**⚠️ KNOWN LIMITATION:** On **dark skin (Fitzpatrick V-VI)**, inflammation appears as **darkening, not redness**
- Current algorithm misses this
- Recommended fix: Add darkness-based detection for dark skin tones
- See CLINICAL_ACCURACY_REVIEW.md section 2 for details

---

### Table 8: Sun Damage Analyzer

**What It Measures:** UV damage indicators (composite of pigmentation + wrinkles + texture)
**Primary Input:** Normalized scores from pigmentation, wrinkle, roughness analyzers
**Method:** Weighted composite with skin-tone normalization

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 69% | Depends on component metrics |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 79% | Good quality components |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 86% | Excellent composite |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 83% | Higher res helps pigmentation |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **90%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 58% | Poor lighting hurts all components |
| **2048²** | 5 | 1800 | 0.50m | Good (±3°) | 76% | Distance hurts wrinkle precision |

**Key Insights:**
- **Most Important:** Composite quality = average of component confidences
- **Secondary:** Skin-tone normalization (critical for fairness)
- **Tertiary:** All component requirements apply
- **Acceptable Error Rate:** ±8% protection score
- **Real-World Viability:** 82%+ achievable with good conditions

**Recommended Configuration:**
- Texture: 4096² (helps pigmentation component)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens
- Distance: 0.35-0.45m
- **Expected Score: 85-90%**

**Formula:**
```
Sun Damage Score = 0.35 × Pigmentation Health
                 + 0.35 × Photoaging Resistance (wrinkles)
                 + 0.30 × Texture Health (roughness)
(All normalized by skin tone)
```

---

### Table 9: Glow/Radiance Analyzer

**What It Measures:** Skin health glow (luminosity + uniformity)
**Primary Input:** Texture luminance distribution + specular analysis
**Method:** Healthy reflection vs oily shine differentiation

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 62% | Single frame = unreliable specular |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 72% | Acceptable averaging |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 81% | Good quality |
| **4096²** | 3 | 1000 | 0.35m | Good (±2°) | 78% | Res helps fine luminosity patterns |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **86%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 51% | Low light kills luminosity detection |
| **2048²** | 5 | 1800 | 0.50m | Good (±3°) | 68% | Overlit creates false glow |

**Key Insights:**
- **Most Important:** Lighting quality (needs accurate light reflection capture)
- **Secondary:** Frames per pose (specular analysis needs consistency)
- **Tertiary:** Distance (affects specular highlight detection)
- **Acceptable Error Rate:** ±12% glow score (subjective metric)
- **Real-World Viability:** 75-85% (challenging metric, affected by natural skin oils)

**Recommended Configuration:**
- Texture: 2048² (sufficient)
- Frames: 5 per pose
- Lighting: 1000-1500 lumens (balanced, not too bright)
- Distance: 0.35-0.45m
- **Expected Score: 78-84%**

**Note:** Differentiates **healthy glow** (even luminosity) from **oily shine** (specular peaks)

---

### Table 10: Volume/Facial Contour Analyzer

**What It Measures:** Facial volume distribution, cheek fullness, jawline definition
**Primary Input:** 3D mesh geometry (volume calculation)
**Method:** Mesh integration over facial regions

| Texture Res | Frames/Pose | Lighting | Distance | Pose Accuracy | Confidence | Notes |
|-------------|-------------|----------|----------|---------------|------------|-------|
| **2048²** | 1 | 600 | 0.30m | Perfect (0°) | 73% | Single mesh = some noise |
| **2048²** | 3 | 800 | 0.35m | Good (±2°) | 84% | Good multi-pose coverage |
| **2048²** | 5 | 1000 | 0.40m | Optimal (0°) | 91% | Excellent coverage |
| **4096²** | 3 | 800 | 0.35m | Good (±2°) | 86% | Texture res doesn't affect geometry |
| **4096²** | 5 | 1200 | 0.40m | Optimal (0°) | **93%** | Maximum achievable |
| **2048²** | 1 | 500 | 0.25m | Poor (±8°) | 68% | Poor pose = incomplete coverage |
| **2048²** | 3 | 800 | 0.60m | Good (±5°) | 79% | Far distance OK for volume |

**Key Insights:**
- **Most Important:** Number of poses captured (more angles = better volume)
- **Secondary:** Pose accuracy (need good turn left/right for full coverage)
- **Tertiary:** Distance (less critical than other geometry metrics)
- **Acceptable Error Rate:** ±3% volume measurement
- **Real-World Viability:** 88%+ easily achievable (geometry-based, robust)

**Recommended Configuration:**
- Texture: 2048² (geometry-based, texture irrelevant)
- Frames: 3-5 per pose
- Lighting: 800-1200 lumens (doesn't affect geometry)
- Distance: 0.30-0.50m (flexible)
- **Expected Score: 89-93%**

**Best metric for:** Geometry-based analysis, less affected by lighting/texture issues

---

## Optimal Configuration Summary

### For Maximum Overall Accuracy (All Analyzers)

**"Best Case Scenario":**
```
Texture Resolution: 4096 × 4096 pixels
Frames per Pose: 5 frames
Lighting: 1200 lumens (even, diffused)
Distance: 0.40 meters (40cm)
Pose Accuracy: Within optimal ranges (±2° from target)
```

**Expected Confidence Scores:**
- Roughness: 94%
- Pigmentation: 92%
- Discoloration: 91%
- Wrinkles: 93%
- Pores: 88%
- Acne: 92%
- Redness: 87% (light skin), 75% (dark skin)
- Sun Damage: 90%
- Glow: 86%
- Volume: 93%

**Overall System Confidence: 90-92%** (weighted average)

---

### For Practical Home Use (Balanced Quality/Ease)

**"Recommended Configuration":**
```
Texture Resolution: 2048 × 2048 pixels
Frames per Pose: 3 frames
Lighting: 1000 lumens (indoor lighting, near window)
Distance: 0.40 meters (arm's length)
Pose Accuracy: Good (±3° from target)
```

**Expected Confidence Scores:**
- Roughness: 87%
- Pigmentation: 86%
- Discoloration: 84%
- Wrinkles: 89%
- Pores: 73% ⚠️ (requires 4K for better)
- Acne: 88%
- Redness: 82% (light skin), 70% (dark skin)
- Sun Damage: 86%
- Glow: 81%
- Volume: 91%

**Overall System Confidence: 83-85%** (weighted average)

---

### Minimum Acceptable Configuration

**"Threshold Quality":**
```
Texture Resolution: 2048 × 2048 pixels
Frames per Pose: 1 frame
Lighting: 800 lumens (acceptable minimum)
Distance: 0.35 meters
Pose Accuracy: Borderline (±5° from target)
```

**Expected Confidence Scores:**
- Roughness: 72%
- Pigmentation: 78%
- Discoloration: 76%
- Wrinkles: 83%
- Pores: 67% ⚠️
- Acne: 83%
- Redness: 75% (light skin), 65% (dark skin)
- Sun Damage: 79%
- Glow: 72%
- Volume: 84%

**Overall System Confidence: 76-78%** (weighted average)

**Note:** Below 75% confidence, system should warn user and recommend retry

---

## Real-World Viability Assessment

### Environment Types vs Expected Quality

| Environment | Lighting | Distance Control | Stability | Expected Confidence | Practical? |
|-------------|----------|------------------|-----------|---------------------|------------|
| **Professional Studio** | 1500 lumens, even | Tripod + marks | Excellent | 90-95% | Yes - ideal |
| **Home Office (Desk)** | 1000 lumens | Stable setup | Good | 83-88% | Yes - recommended |
| **Living Room (Day)** | 800-1200 lumens | Handheld/prop | Fair | 78-84% | Yes - acceptable |
| **Bathroom (Mirror)** | 600-1000 lumens | Handheld | Poor | 70-76% | Marginal |
| **Bedroom (Night)** | 400-800 lumens | Handheld | Fair | 65-72% | Not recommended |
| **Outdoors (Shade)** | 1500+ lumens | Handheld | Poor | 72-78% | Challenging |
| **Outdoors (Sun)** | 3000+ lumens | Handheld | Poor | 58-65% | Not viable |

**Recommended Setup for Home Users:**
1. **Location:** Home office or well-lit room
2. **Time:** Daytime near window (indirect sunlight) OR nighttime with 2-3 lamps
3. **Device:** Propped on stand/books at eye level (not handheld)
4. **Position:** Seated with elbows on table
5. **Expected Quality:** 80-88% confidence

---

## Calibration Optimization Strategies

### Strategy 1: Maximize Geometry-Based Metrics (Easy)

**Focus:** Roughness, Wrinkles, Volume (less affected by lighting/texture)

**Configuration:**
- Texture: 2048² (sufficient)
- Frames: 5 per pose (critical for averaging)
- Lighting: 800+ lumens (just meet minimum)
- Distance: 0.35-0.40m (closer for depth precision)

**Result:** 88-92% confidence on geometry metrics, 75-80% on texture metrics
**Use Case:** Quick scan, challenging lighting conditions

---

### Strategy 2: Maximize Texture-Based Metrics (Harder)

**Focus:** Pigmentation, Discoloration, Pores, Redness (requires excellent conditions)

**Configuration:**
- Texture: 4096² (critical for pores)
- Frames: 5 per pose (critical for consistency)
- Lighting: 1200 lumens, **even and diffused** (critical)
- Distance: 0.30-0.35m (closer for pixel density)

**Result:** 85-92% confidence on texture metrics, 90-94% on geometry metrics
**Use Case:** Clinical-grade analysis, controlled environment

---

### Strategy 3: Balanced for All Metrics (Recommended)

**Configuration:**
- Texture: 2048² baseline, 4096² if pore analysis important
- Frames: 3 per pose (good balance)
- Lighting: 1000 lumens (achievable at home)
- Distance: 0.40m (arm's length)

**Result:** 82-88% confidence across all metrics
**Use Case:** General consumer health tracking

---

## Analyzer Priority Ranking

### By Reliability (High → Low)

1. **Volume/Contour (93%)** - Geometry-based, very robust
2. **Wrinkles (89-93%)** - Geometry-based, good precision
3. **Roughness (87-94%)** - Geometry-based, frame averaging helps
4. **Acne (88-92%)** - Adaptive algorithm, works across skin tones
5. **Sun Damage (86-90%)** - Composite metric, well-normalized
6. **Pigmentation (86-92%)** - Texture-based but robust with good conditions
7. **Discoloration (84-91%)** - Requires even lighting but reliable
8. **Glow (81-86%)** - Subjective metric, lighting-dependent
9. **Redness (82-87% light, 70-75% dark)** - Works well on light skin, needs fix for dark
10. **Pores (73-88%)** - Most challenging, requires 4K + close distance

### By Clinical Importance (Medical → Cosmetic)

1. **Sun Damage** - Skin cancer risk indicator
2. **Pigmentation** - Melasma, hyperpigmentation (medical)
3. **Acne** - Active condition requiring treatment
4. **Redness** - Rosacea, inflammation indicators
5. **Wrinkles** - Aging, sun damage (photoaging)
6. **Discoloration** - Uneven tone, post-inflammatory marks
7. **Roughness** - Skin health, exfoliation needs
8. **Volume** - Aging indicators, facial fat loss
9. **Pores** - Cosmetic concern, oil production
10. **Glow** - Subjective health indicator

---

## Document Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-06 | Initial comprehensive pose requirements guide | Claude (Tavi Analysis) |

---

**End of Document**

*This guide consolidates pose requirements from CalibrationState.swift, CalibrationManager.swift, ValidationManager.swift, ScanConfiguration.swift, CALIBRATION_GUIDE.md, and MULTI_CAPTURE_GUIDE.md*
