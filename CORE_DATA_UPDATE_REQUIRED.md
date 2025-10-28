# CORE DATA SCHEMA UPDATE REQUIRED

**Status**: ⏳ USER ACTION REQUIRED (5 minutes in Xcode)
**Date**: October 28, 2025

---

## WHY THIS UPDATE IS NEEDED

The app now saves comprehensive metrics data to Core Data:
- ✅ EmotionalMetrics (JSON encoded)
- ✅ ClinicalMetrics (JSON encoded)
- ✅ Device information (model, OS version)

These new fields enable:
- Before/after comparison ("WOW! Up 8 points!")
- Historical tracking over time
- Full metrics persistence
- Device-specific tracking

---

## STEP-BY-STEP INSTRUCTIONS

### 1. Open the Core Data Model in Xcode

1. Open `Tavi.xcodeproj` in Xcode
2. Navigate to the file: `Tavi/Core/StorageKit/Tavi.xcdatamodeld`
3. Click on the file to open the Core Data model editor

### 2. Select the SessionResult Entity

1. In the left sidebar, find and click on **SessionResult** entity
2. You should see the attributes list on the right side

### 3. Add New Attributes

Click the **"+"** button at the bottom of the Attributes section to add each of these:

#### Attribute 1: `deviceOS`
- **Name**: `deviceOS`
- **Type**: `String`
- **Optional**: ✅ UNCHECKED (required field)
- **Default Value**: (leave empty)

#### Attribute 2: `emotionalMetricsData`
- **Name**: `emotionalMetricsData`
- **Type**: `Binary Data`
- **Optional**: ✅ CHECKED (optional field)
- **Allow External Storage**: ✅ UNCHECKED (data is small)

#### Attribute 3: `clinicalMetricsData`
- **Name**: `clinicalMetricsData`
- **Type**: `Binary Data`
- **Optional**: ✅ CHECKED (optional field)
- **Allow External Storage**: ✅ UNCHECKED (data is small)

### 4. Verify the Attributes

Your SessionResult entity should now have these attributes (among others):

```
SessionResult
├── id: UUID
├── date: Date
├── deviceModel: String
├── deviceOS: String                    ← NEW
├── overallScore: Double
├── textureAvg: Double
├── pigmentationAvg: Double
├── blurQuality: Double
├── moistureSpecular: Double
├── moistureSmoothness: Double
├── emotionalMetricsData: Binary Data   ← NEW
└── clinicalMetricsData: Binary Data    ← NEW
```

### 5. Save the Changes

1. Press **⌘S** to save the Core Data model
2. Xcode will automatically generate the updated model

### 6. Clean and Rebuild

1. Press **⇧⌘K** (Shift-Cmd-K) to clean build folder
2. Press **⌘B** (Cmd-B) to build

---

## WHAT HAPPENS AFTER THE UPDATE

Once you update the schema and rebuild:

✅ **New scans** will save:
- Full emotional metrics (JSON)
- Full clinical metrics (JSON)
- Device OS information

✅ **Before/after comparisons** will work:
- "WOW! Radiance up 8 points!"
- "Smoothness improved by 12%"

✅ **Historical tracking** enabled:
- Track skin improvements over weeks/months
- See trends in metrics over time

---

## TROUBLESHOOTING

### If you get a "model version mismatch" error:

**Option 1: Reset Core Data (Development Only)**
1. Delete the app from your device/simulator
2. Clean build folder (⇧⌘K)
3. Rebuild (⌘B)
4. Run again

**Option 2: Create Model Version (Recommended for Production)**
1. In Xcode, select `Tavi.xcdatamodeld`
2. Menu: Editor → Add Model Version
3. Name it "Tavi 2"
4. Select `Tavi.xcdatamodeld` in Project Navigator
5. In File Inspector (right panel), set "Current Model Version" to "Tavi 2"
6. Add the new attributes to "Tavi 2"
7. Implement lightweight migration (automatic for simple attribute additions)

For now, **Option 1 is fine** since you're in development.

---

## VERIFICATION

After updating and rebuilding, verify everything works:

1. ✅ Build succeeds (no errors)
2. ✅ Run a face scan
3. ✅ Results display properly
4. ✅ Run a second scan
5. ✅ Improvements show (e.g., "Up 5 points!")
6. ✅ Check Xcode console for "✅ Session saved successfully!"

---

## FILES THAT USE THESE FIELDS

### SessionResult.swift
Location: `/Users/apple/Desktop/Tavi/Tavi/Core/StorageKit/SessionResult.swift`

Properties defined (lines 20, 21, 47, 48):
```swift
@NSManaged public var deviceModel: String
@NSManaged public var deviceOS: String             // NEW FIELD
@NSManaged public var emotionalMetricsData: Data?  // NEW FIELD
@NSManaged public var clinicalMetricsData: Data?   // NEW FIELD
```

### EmotionalScan3DFlowView.swift
Location: `/Users/apple/Desktop/Tavi/Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift`

Saves data (lines 352-384):
```swift
private func saveToCoreData(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) {
    let session = SessionResult(context: viewContext)

    // Device info
    session.deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

    // Encode and save full metrics
    if let emotionalData = try? JSONEncoder().encode(emotionalMetrics) {
        session.emotionalMetricsData = emotionalData
    }
    if let clinicalData = try? JSONEncoder().encode(clinicalMetrics) {
        session.clinicalMetricsData = clinicalData
    }

    try viewContext.save()
}
```

---

## ESTIMATED TIME

⏱️ **Total**: 5 minutes
- Opening Core Data model: 1 min
- Adding 3 attributes: 2 min
- Clean build: 1 min
- Test run: 1 min

---

## NEXT STEPS AFTER UPDATE

1. ✅ Complete this Core Data update
2. ✅ Build and test the app
3. 🔮 Optional: Test with diverse skin tones
4. 🔮 Optional: Test in various lighting conditions
5. 🚀 Ship your app!

---

**Questions?** See `COMPREHENSIVE_FIXES_APPLIED.md` for full context.
