# Onboarding & Polish - Quick Start Guide

## 🎯 What You Got

A polished, professional app with:
- ✅ 3-card onboarding flow (shows on first launch)
- ✅ Haptic feedback for key events
- ✅ Loading overlays for long operations
- ✅ Complete design system (Airbnb/Uber style)
- ✅ Updated UI components

---

## 🎨 Design System at a Glance

### Colors
```swift
DesignSystem.Colors.accent           // Teal blue #007BA3
DesignSystem.Colors.textPrimary      // Black
DesignSystem.Colors.textSecondary    // Medium gray
DesignSystem.Colors.cardBackground   // White
DesignSystem.Colors.backgroundSecondary  // Light gray
```

### Typography
```swift
DesignSystem.Typography.title2       // 24pt bold - Screen titles
DesignSystem.Typography.headline     // 17pt semibold - Card titles
DesignSystem.Typography.body         // 17pt regular - Body text
DesignSystem.Typography.caption      // 12pt - Metadata
```

### Spacing
```swift
DesignSystem.Spacing.small    // 12pt
DesignSystem.Spacing.medium   // 16pt
DesignSystem.Spacing.large    // 20pt
DesignSystem.Spacing.xLarge   // 24pt
```

### Shadows
```swift
.cardShadow()       // Light shadow for cards
.elevatedShadow()   // Medium shadow
.modalShadow()      // Heavy shadow for modals
```

---

## 📱 Onboarding

### What Users See

**First Launch Only**:
1. **Card 1**: Good Lighting (sun icon, orange)
2. **Card 2**: Frame Your Face (face icon, teal)
3. **Card 3**: Hold Still (hand icon, blue)

Each card has:
- Large icon
- Bold title
- Description
- 4 helpful tips with checkmarks
- "Next" or "Get Started" button
- "Skip" option

### How It Works

Automatically shows on first launch:
- Non-dismissible (must complete or skip)
- Persists completion in UserDefaults
- Never shows again after completion
- Haptic feedback on buttons

### Testing

To see onboarding again:
```swift
// Delete and reinstall app, or:
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
```

---

## 🎮 Haptic Feedback

### Already Integrated

**Calibration Success**:
```swift
// Fires automatically when calibration turns green
HapticManager.shared.calibrationSuccess()
```

**Capture Complete**:
```swift
// Fires automatically when multi-frame capture finishes
HapticManager.shared.captureComplete() // Double haptic!
```

**Button Taps**:
```swift
// All PrimaryButton instances have haptic
PrimaryButton(title: "Analyze") { }
```

### Available Haptics

```swift
HapticManager.shared.light()           // Button tap
HapticManager.shared.medium()          // Toggle
HapticManager.shared.heavy()           // Important action
HapticManager.shared.success()         // Success
HapticManager.shared.warning()         // Warning
HapticManager.shared.error()           // Error
HapticManager.shared.selection()       // Picker change
```

### Adding Haptics

```swift
Button("Action") {
    HapticManager.shared.light()
    performAction()
}
```

---

## ⏳ Loading Overlays

### Quick Usage

```swift
// In ViewModel
@Published var isProcessing = false

func processData() async {
    isProcessing = true
    defer { isProcessing = false }

    // Long operation...
}

// In View
ContentView()
    .loadingOverlay(isLoading: viewModel.isProcessing, message: "Processing...")
```

### Full Overlay

```swift
ZStack {
    ContentView()

    if isLoading {
        LoadingOverlay(message: "Analyzing skin...")
    }
}
```

### Inline Loading

```swift
if isLoading {
    InlineLoadingView(message: "Loading results...")
}
```

---

## 🎨 Using Design System

### New View Example

```swift
struct MyView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Title
            Text("Screen Title")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Card
            CardView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Card Title")
                        .font(DesignSystem.Typography.headline)

                    Text("Body text here")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Button
            Button("Continue") { }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(DesignSystem.Spacing.large)
        .background(DesignSystem.Colors.backgroundSecondary)
    }
}
```

### Button Styles

**Primary (Accent)**:
```swift
Button("Get Started") { }
    .buttonStyle(PrimaryButtonStyle())
```

**Secondary (Outlined)**:
```swift
Button("Skip") { }
    .buttonStyle(SecondaryButtonStyle())
```

### Card Style

```swift
CardView {
    // Content
}
// Automatically has:
// - White background
// - 12pt rounded corners
// - Subtle shadow
// - 16pt padding
```

---

## 📋 UI Guidelines

### Typography

**Do**:
- Headlines: Bold black
- Body: Medium gray
- Captions: Light gray

**Don't**:
- Mix font weights randomly
- Use colors for hierarchy (use size/weight instead)

### Colors

**Do**:
- Teal for CTAs only
- Black for headlines
- Gray for body text
- Status colors (green/orange/red) for feedback

**Don't**:
- Use multiple accent colors
- Use gradients
- Use loud/bright colors

### Spacing

**Do**:
- Use design system spacing values
- Large spacing between sections (20pt)
- Medium spacing between elements (16pt)
- Small spacing within groups (12pt)

**Don't**:
- Use arbitrary values
- Inconsistent spacing

### Cards

**Do**:
- White background
- 12-16pt rounded corners
- Subtle shadow
- Proper padding (16pt)

**Don't**:
- Heavy shadows
- Colored backgrounds
- Sharp corners

---

## 🎯 Design Principles

### Airbnb/Uber Style

✅ **Flat, trustworthy feel**
- No gradients
- No skeuomorphism
- No loud hues

✅ **Single accent color**
- Teal blue for all CTAs
- Consistent throughout app

✅ **Bold, clear hierarchy**
- Black headlines
- Gray body text
- Proper spacing

✅ **Rounded, friendly shapes**
- 12-16pt corners
- Subtle shadows
- Clean edges

---

## 🔧 Common Tasks

### Add Loading to Function

```swift
@Published var isLoading = false

func doWork() async {
    isLoading = true
    defer { isLoading = false }
    // Work here
}
```

### Add Haptic to Action

```swift
Button("Action") {
    HapticManager.shared.light()
    performAction()
}
```

### Create Styled Card

```swift
CardView {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
        Text("Title")
            .font(DesignSystem.Typography.headline)
        Text("Description")
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
}
```

### Add Screen Background

```swift
VStack {
    // Content
}
.background(DesignSystem.Colors.backgroundSecondary)
```

---

## 📊 Visual Examples

### Before & After

**Before**:
```
Mixed colors, inconsistent spacing, no haptics, no onboarding
```

**After**:
```
┌─────────────────────────────────┐
│  Bold Black Headline            │
│  Medium gray body text          │
│                                 │
│  ┌─────────────────────────┐    │
│  │  White Card             │    │
│  │  12pt rounded corners   │    │
│  │  Subtle shadow          │    │
│  └─────────────────────────┘    │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Teal CTA Button       │    │
│  └─────────────────────────┘    │
└─────────────────────────────────┘

✓ Onboarding on first launch
✓ Haptics for key events
✓ Loading overlays
✓ Consistent design
```

---

## ✅ Quick Checklist

### Design System
- [ ] All text uses DesignSystem.Typography
- [ ] All colors use DesignSystem.Colors
- [ ] All spacing uses DesignSystem.Spacing
- [ ] Cards use CardView
- [ ] Buttons use PrimaryButtonStyle/SecondaryButtonStyle

### Haptics
- [ ] Calibration has haptic
- [ ] Capture has haptic
- [ ] Buttons have haptics
- [ ] Important actions have haptics

### Loading
- [ ] Long operations show loading overlay
- [ ] UI disabled during loading
- [ ] Clear message displayed

### Onboarding
- [ ] Shows on first launch
- [ ] Can be skipped
- [ ] Never shows again after completion
- [ ] Has haptic feedback

---

## 🎉 Summary

**Onboarding**:
- 3 cards with clear instructions
- Automatic on first launch
- Skip or complete flow

**Haptics**:
- Calibration success ✓
- Capture complete ✓✓
- Button taps ✓

**Loading**:
- Full-screen overlay
- Disabled UI
- Custom messages

**Design System**:
- Airbnb/Uber style
- Teal accent
- Bold black headlines
- Medium gray body
- Rounded cards
- Subtle shadows

All ready to use! Just import and follow the examples above.

Happy polishing! ✨
