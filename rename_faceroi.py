#!/usr/bin/env python3
"""
Rename FaceROI to Face3DROI in all FaceScan3D files
"""

import os
import re

# Files to update (excluding the ones already updated)
files_to_update = [
    'Tavi/Features/FaceScan3D/Utilities/MetricsVisualizer.swift',
    'Tavi/Features/FaceScan3D/Models/Face3DSummary.swift',
    'Tavi/Features/FaceScan3D/Utilities/Face3DMetricsAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/TextureQualityValidator.swift',
    'Tavi/Features/FaceScan3D/Views/Face3DMetricsResultsView.swift',
    'Tavi/Features/FaceScan3D/Utilities/HeatmapOverlayGenerator.swift',
    'Tavi/Features/FaceScan3D/Utilities/DiscolorationAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/ROIMaskGenerator.swift',
]

for file_path in files_to_update:
    full_path = f'/Users/apple/Desktop/Tavi/{file_path}'

    if not os.path.exists(full_path):
        print(f"⏭️  Skipping (not found): {file_path}")
        continue

    try:
        with open(full_path, 'r') as f:
            content = f.read()

        # Replace FaceROI with Face3DROI
        # But be careful not to replace things like "FaceROISet" from 2D system
        updated_content = content.replace('FaceROI', 'Face3DROI')

        if content != updated_content:
            with open(full_path, 'w') as f:
                f.write(updated_content)

            count = content.count('FaceROI')
            print(f"✅ Updated {count} occurrence(s) in: {file_path}")
        else:
            print(f"⏭️  No changes needed: {file_path}")

    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")

print("\n✅ Renaming complete!")
