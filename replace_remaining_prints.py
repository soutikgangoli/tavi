#!/usr/bin/env python3
"""
Script to replace print() statements with AppLogger calls in Swift files.
This script intelligently categorizes log messages and chooses appropriate log levels.
"""

import re
import os
from pathlib import Path

# File categories and their corresponding logger categories
FILE_CATEGORIES = {
    'metrics': ['Metrics/', 'Analyzer'],
    'mesh': ['Processing/', 'Mesh'],
    'storage': ['Storage', 'Persistence', 'CoreData'],
    'faceScan': ['FaceScan', 'Scan'],
    'export': ['Export/'],
    'ui': ['/UI/', 'View'],
    'auth': ['Auth'],
    'app': []  # default
}

def get_logger_category(filepath):
    """Determine appropriate AppLogger category based on file path."""
    filepath_str = str(filepath)

    for category, patterns in FILE_CATEGORIES.items():
        if any(pattern in filepath_str for pattern in patterns):
            return f'AppLogger.{category}'

    return 'AppLogger.app'

def get_log_level(message):
    """Determine log level based on message content."""
    # Error indicators
    if any(indicator in message for indicator in ['❌', 'ERROR', 'Failed', 'failed', 'Error']):
        return 'error'

    # Warning indicators
    if any(indicator in message for indicator in ['⚠️', 'WARNING', 'Warning']):
        return 'warning'

    # Success/completion indicators
    if any(indicator in message for indicator in ['✅', '✓', 'Complete', 'Success', 'successful']):
        return 'info'

    # Debug indicators (messages starting with spaces)
    if message.strip() != message and message.startswith(' '):
        return 'debug'

    # Default to info
    return 'info'

def replace_print_statements(filepath):
    """Replace print() statements with AppLogger calls in a Swift file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        logger_category = get_logger_category(filepath)

        # Pattern to match print statements
        # This handles: print("message") and print("message", terminator: "")
        pattern = r'print\((.*?)\)'

        def replace_func(match):
            args = match.group(1).strip()

            # Skip if it's a complex print statement with variables
            if '\\(' in args and ')' in args:
                # Extract the message to determine log level
                # This is a string interpolation case
                log_level = get_log_level(args)
                return f'{logger_category}.{log_level}({args})'

            # Simple string case
            if args.startswith('"') and args.endswith('"'):
                message = args[1:-1]  # Remove quotes
                log_level = get_log_level(message)
                return f'{logger_category}.{log_level}("{message}")'

            # Default case - just replace with info level
            return f'{logger_category}.info({args})'

        # Replace all print statements
        new_content = re.sub(pattern, replace_func, content)

        if new_content != original_content:
            # Create backup
            backup_path = f"{filepath}.backup"
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(original_content)

            # Write new content
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)

            return True

        return False

    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all remaining files."""
    # List of files with print statements
    files_to_process = [
        "Tavi/Core/ModelsKit/AnalysisTypes.swift",
        "Tavi/Core/Utilities/BiometricAuth.swift",
        "Tavi/Core/Utilities/CrashReporter.swift",
        "Tavi/Core/Utilities/AsyncTimeout.swift",
        "Tavi/Core/StorageKit/Migration/DataBackupView.swift",
        "Tavi/Core/StorageKit/PersistenceController.swift",
        "Tavi/Features/Results/ResultsViewModel.swift",
        "Tavi/Features/Social/SocialSharingView.swift",
        "Tavi/Features/FaceScan3D/Metrics/AcneAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/SunDamageAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/PigmentationMapper.swift",
        "Tavi/Features/FaceScan3D/Metrics/PoreAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/MeshTopologyAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/WrinkleAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/RednessAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Metrics/TemporalTracker.swift",
        "Tavi/Features/FaceScan3D/Metrics/SkinElasticity.swift",
        "Tavi/Features/FaceScan3D/Metrics/HydrationEstimator.swift",
        "Tavi/Features/FaceScan3D/Metrics/GlowAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Utilities/RoughnessAnalyzer.swift",
        "Tavi/Features/FaceScan3D/Utilities/EdgeCaseDetector.swift",
        "Tavi/Features/FaceScan3D/Utilities/ExportManager.swift",
        "Tavi/Features/FaceScan3D/Utilities/TextureBaker.swift",
        "Tavi/Features/FaceScan3D/Utilities/MeshTextureExporter.swift",
        "Tavi/Features/FaceScan3D/Utilities/TextureCapture.swift",
        "Tavi/Features/FaceScan3D/Utilities/ColorTemperatureNormalizer.swift",
        "Tavi/Features/FaceScan3D/Utilities/AlbedoEstimator.swift",
        "Tavi/Features/FaceScan3D/Views/ARFaceTrackingViewController.swift",
        "Tavi/Features/FaceScan3D/Views/Face3DMetricsResultsView.swift",
        "Tavi/Features/FaceScan3D/Views/TexturedMeshPreviewView.swift",
        "Tavi/Features/FaceScan3D/Views/EmotionalScan3DFlowView.swift",
        "Tavi/Features/FaceScan3D/ViewModels/FaceScan3DViewModel.swift",
        "Tavi/Features/FaceScan3D/UI/LightingCalibrationView.swift",
        "Tavi/Features/FaceScan3D/FaceScan3DAPI.swift",
        "Tavi/Features/Export/PDFReportGenerator.swift",
        "Tavi/Shared/UI/HeatmapView.swift",
        "Tavi/Shared/UI/FancyLoadingScreen.swift",
        "Tavi/Shared/UI/PrimaryButton.swift",
        "TaviTests/AnalyzerTests.swift",
    ]

    processed = 0
    skipped = 0

    print("Replacing print() statements with AppLogger calls...")
    print(f"Processing {len(files_to_process)} files\n")

    for filepath in files_to_process:
        if os.path.exists(filepath):
            if replace_print_statements(filepath):
                print(f"✅ Processed: {filepath}")
                processed += 1
            else:
                print(f"⏭️  Skipped (no changes): {filepath}")
                skipped += 1
        else:
            print(f"❌ File not found: {filepath}")
            skipped += 1

    print(f"\nDone!")
    print(f"Processed: {processed} files")
    print(f"Skipped: {skipped} files")
    print(f"Backups created with .backup extension")
    print(f"\nReview changes and remove .backup files if satisfied:")
    print(f"  find . -name '*.backup' -delete")

if __name__ == "__main__":
    main()
