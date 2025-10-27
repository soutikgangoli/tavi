# Core Data Setup Instructions

## ⚠️ IMPORTANT: Core Data Model Update Required

The code has been updated to save and load **EmotionalMetrics** and **Face3DMetrics** data, but the Core Data model file needs to be updated in Xcode to add the new attributes.

## Required Steps in Xcode

### Option 1: Find and Update Existing Model (Preferred)

1. **Open Xcode**
   ```
   Open Tavi.xcodeproj
   ```

2. **Find TaviModel.xcdatamodeld**
   - In Xcode's Project Navigator (left sidebar)
   - Look for `TaviModel.xcdatamodeld` or similar
   - It might be in the root or in a `Models` folder
   - Click on it to open the Core Data editor

3. **Select SessionResult Entity**
   - In the Core Data editor, select `SessionResult` from the entities list

4. **Add New Attributes**
   Click the `+` button at the bottom of the Attributes section and add:

   | Attribute Name | Type | Optional | Default |
   |---------------|------|----------|---------|
   | `deviceOS` | String | No | - |
   | `emotionalMetricsData` | Binary Data | Yes | - |
   | `clinicalMetricsData` | Binary Data | Yes | - |

5. **Save the Model**
   - File → Save (⌘S)

6. **Enable Lightweight Migration (if not already)**
   - Open `PersistenceController.swift`
   - Verify this code exists in the `init` method (already there):
   ```swift
   container.loadPersistentStores { description, error in
       // Migration happens automatically
   }
   ```

---

### Option 2: Create New Model File (If missing)

If you can't find `TaviModel.xcdatamodeld`:

1. **Create New Core Data Model**
   - File → New → File...
   - Choose "Data Model" under Core Data
   - Name it "TaviModel"
   - Save it in the project

2. **Add SessionResult Entity**
   - Click "Add Entity" button
   - Name it `SessionResult`
   - Set Module to "Current Product Module"
   - Set Codegen to "Manual/None" (important!)

3. **Add All Attributes**

   **Required Attributes:**
   - `id`: UUID
   - `date`: Date
   - `deviceModel`: String
   - `deviceOS`: String ← NEW

   **Score Attributes:**
   - `blurQuality`: Double
   - `textureAvg`: Double
   - `pigmentationAvg`: Double
   - `discolorationIndex`: Double
   - `moistureSpecular`: Double
   - `moistureSmoothness`: Double
   - `overallScore`: Double

   **Regional Scores:**
   - `leftCheekScore`: Double
   - `rightCheekScore`: Double
   - `foreheadScore`: Double
   - `chinScore`: Double

   **Image Data (all Optional):**
   - `thumbnail`: Binary Data
   - `heatmapComposite`: Binary Data
   - `heatmapSharpness`: Binary Data
   - `heatmapTexture`: Binary Data
   - `heatmapPigmentation`: Binary Data
   - `heatmapMoisture`: Binary Data

   **Metrics Data (Optional):**
   - `emotionalMetricsData`: Binary Data ← NEW
   - `clinicalMetricsData`: Binary Data ← NEW

4. **Save and Build**

---

## Verifying the Setup

### Build the Project

1. **Clean Build Folder**
   ```
   Product → Clean Build Folder (⇧⌘K)
   ```

2. **Build**
   ```
   Product → Build (⌘B)
   ```

3. **Check for Errors**
   - If you get "Unknown attribute name: deviceOS"
     → Model wasn't updated correctly, retry above steps

   - If you get "Cannot find TaviModel in scope"
     → Model file name doesn't match, check PersistenceController.swift line 65

---

## Testing the Flow

### First Scan (Should Work)

1. Run the app
2. Complete onboarding
3. Tap "Scan Now"
4. Complete 3D scan (7 poses)
5. See results with glow score
6. Check console for: `✅ Session saved successfully!`

### Second Scan (Test Improvements)

1. Do another scan (next day or same day)
2. Console should show:
   ```
   ✅ Loaded previous clinical metrics from [date]
   ✅ Loaded previous emotional metrics from [date]
   ✅ Session saved successfully!
   ```

3. Results should show:
   - **Improvements section** with "+X%" changes
   - "WOW! Your glow score jumped X points!" if improved
   - Comparison to previous scan

---

## Troubleshooting

### "Cannot load persistent store"

**Cause:** Model schema changed but migration failed

**Fix:**
1. Delete the app from simulator/device
2. Clean build folder (⇧⌘K)
3. Rebuild
4. This forces fresh Core Data database creation

### "Unknown attribute: deviceOS"

**Cause:** Core Data model file wasn't updated

**Fix:**
1. Open `.xcdatamodeld` file
2. Verify `deviceOS` attribute exists on SessionResult entity
3. Verify it's type String, not optional
4. Save model
5. Clean build folder
6. Rebuild

### "Property 'emotionalMetricsData' not found"

**Cause:** Model attribute name doesn't match code

**Fix:**
1. Check spelling in Core Data model
2. Should be exactly: `emotionalMetricsData` (camelCase)
3. Type should be: Binary Data
4. Should be: Optional

### Improvements Don't Show

**Possible causes:**
1. Only 1 scan exists (need 2+ for comparison)
2. Previous scan didn't save `clinicalMetricsData`
3. Decoding failed

**Debug:**
Check console for:
```
ℹ️ No previous clinical metrics found
```

If you see this after 2+ scans:
1. Check previous scan has `clinicalMetricsData` != nil
2. Try deleting app and doing 2 fresh scans

---

## What Happens After Setup

### First Scan Flow
```
User completes scan
  ↓
Clinical metrics computed (Face3DMetrics)
  ↓
Emotional metrics generated (EmotionalMetrics)
  ↓
Saved to Core Data:
  - emotionalMetricsData (JSON)
  - clinicalMetricsData (JSON)
  - deviceOS: "iOS 17.0"
  - all score fields
  ↓
Results shown:
  - Glow score: 73
  - Concerns: Real, based on scores
  - Advice: Personalized
  - NO improvements (first scan)
```

### Second Scan Flow
```
User completes scan
  ↓
Load previous metrics from Core Data
  ↓
Clinical metrics computed (new)
  ↓
Emotional metrics generated
  WITH comparisons to previous
  ↓
Improvements detected:
  - "Smoother skin texture +12%"
  - "WOW! Your glow score jumped 8 points!"
  ↓
Saved to Core Data (new session)
  ↓
Results shown:
  - Glow score: 81
  - Improvements section (✨ NEW)
  - Updated concerns
  - Updated advice
```

---

## Success Indicators

You'll know it's working when:

✅ App builds without errors
✅ First scan saves successfully
✅ Console shows: "✅ Session saved successfully!"
✅ Home screen shows latest scan
✅ Second scan loads previous data
✅ Console shows: "✅ Loaded previous clinical metrics..."
✅ Results show improvements section
✅ "WOW! You improved X points!" appears

---

## Alternative: Skip Core Data Model Update

If you want to test without updating the model file:

1. The app will crash when trying to save `deviceOS`, `emotionalMetricsData`, or `clinicalMetricsData`
2. Comment out these lines in `EmotionalScan3DFlowView.swift:saveToCoreData()`:
   ```swift
   // session.deviceOS = "..." // TEMP: Comment out
   // session.emotionalMetricsData = ... // TEMP: Comment out
   // session.clinicalMetricsData = ... // TEMP: Comment out
   ```

3. Improvements won't work, but basic save will work

**Not recommended** - Just update the model, it takes 2 minutes!

---

## Questions?

If Core Data model update doesn't work:
1. Check Xcode version (need 14+)
2. Verify model file exists
3. Try creating new model file
4. Check PersistenceController container name matches model name
