# Core Data Model Setup Instructions

Since `.xcdatamodeld` files must be created in Xcode, follow these steps:

## 1. Create the Core Data Model File

1. In Xcode, select `Tavi/Core/StorageKit` folder
2. Go to **File → New → File...**
3. Choose **Data Model** under Core Data section
4. Name it `TaviModel`
5. Click **Create**

## 2. Add SessionResult Entity

1. Click the **Add Entity** button at the bottom
2. Name the entity `SessionResult`
3. Set **Class Name** to `SessionResult` in the Data Model Inspector
4. Set **Module** to `Tavi` (or leave as "Current Product Module")
5. Set **Codegen** to `Manual/None` (we already have SessionResult.swift)

## 3. Add Attributes

Click the `+` button under **Attributes** and add each of these:

### Identity & Metadata
- `id` → Type: **UUID**
- `date` → Type: **Date**
- `deviceModel` → Type: **String**

### Score Metrics (all Type: **Double**)
- `blurQuality`
- `textureAvg`
- `pigmentationAvg`
- `discolorationIndex`
- `moistureSpecular`
- `moistureSmoothness`
- `overallScore`

### ROI Scores (all Type: **Double**)
- `leftCheekScore`
- `rightCheekScore`
- `foreheadScore`
- `chinScore`

### Images (all Type: **Binary Data**, Optional: ✓, Allows External Storage: ✓)
- `thumbnail`
- `heatmapComposite`
- `heatmapSharpness`
- `heatmapTexture`
- `heatmapPigmentation`
- `heatmapMoisture`

## 4. Important Settings for Image Attributes

For each image attribute (`thumbnail`, `heatmapComposite`, etc.):
1. Select the attribute
2. In the **Data Model Inspector** (right panel):
   - Check **Optional** ✓
   - Check **Allows External Storage** ✓ (enables efficient large binary storage)

## 5. Verify Setup

After creating the model:
- Build the project (⌘B) to verify no errors
- The model file should appear as `TaviModel.xcdatamodeld` in the project navigator
- PersistenceController.swift should compile without errors

## 6. Next Steps

Once the Core Data model is created, the following are ready to use:
- ✅ `PersistenceController.swift` - Core Data stack manager
- ✅ `SessionResult.swift` - Entity class with all properties
- ⏭️ Update `TaviApp.swift` to inject persistence controller
- ⏭️ Create Results UI views

---

**Note**: This is the only step that requires Xcode's GUI. All other files are already created programmatically.
