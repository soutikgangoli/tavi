#!/usr/bin/env python3
"""
Rename ROIMetrics to ROI3DMetrics in all FaceScan3D files
"""

import os
import re

# Files to update in FaceScan3D module
files_to_update = [
    'Tavi/Features/FaceScan3D/Models/Face3DSummary.swift',
    'Tavi/Features/FaceScan3D/Utilities/Face3DMetricsAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/MetricsVisualizer.swift',
    'Tavi/Features/FaceScan3D/Utilities/TextureQualityValidator.swift',
    'Tavi/Features/FaceScan3D/Views/Face3DMetricsResultsView.swift',
    'Tavi/Features/FaceScan3D/Views/Face3DResultsView.swift',
    'Tavi/Features/FaceScan3D/Utilities/HeatmapOverlayGenerator.swift',
    'Tavi/Features/FaceScan3D/Utilities/DiscolorationAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/RoughnessAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/PigmentationAnalyzer.swift',
    'Tavi/Features/FaceScan3D/Utilities/SpecularAnalyzer.swift',
    'Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift',
]

for file_path in files_to_update:
    full_path = f'/Users/apple/Desktop/Tavi/{file_path}'

    if not os.path.exists(full_path):
        print(f"⏭️  Skipping (not found): {file_path}")
        continue

    try:
        with open(full_path, 'r') as f:
            content = f.read()

        # Replace ROIMetrics with ROI3DMetrics
        updated_content = content.replace('ROIMetrics', 'ROI3DMetrics')

        if content != updated_content:
            with open(full_path, 'w') as f:
                f.write(updated_content)

            count = content.count('ROIMetrics')
            print(f"✅ Updated {count} occurrence(s) in: {file_path}")
        else:
            print(f"⏭️  No changes needed: {file_path}")

    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")

print("\n✅ ROIMetrics renaming complete!")
