//
//  ContentView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

struct ContentView: View {

    private let cameraSession = CameraSession()
    private let capabilities = DeviceCapabilities.current

    var body: some View {
        List {
            Section("Scan Modes") {
                NavigationLink {
                    CameraView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("2D Skin Analysis", systemImage: "camera.fill")
                            .font(.headline)
                        Text("Fast multi-frame capture with 2D metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if capabilities.supportsTrueDepth {
                    NavigationLink {
                        Scan3DFlowView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("3D Face Scan", systemImage: "face.dashed")
                                .font(.headline)
                            Text("ARKit TrueDepth scan with 3D metrics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    HStack {
                        Label("3D Face Scan", systemImage: "face.dashed")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Requires TrueDepth")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("History") {
                NavigationLink {
                    ResultsHistoryView()
                } label: {
                    Label("Analysis History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Debug") {
                NavigationLink {
                    DebugScreen(cameraSession: cameraSession)
                } label: {
                    Label("Debug Screen", systemImage: "hammer.fill")
                }
            }

            Section("Settings") {
                NavigationLink {
                    CaptureSettingsView()
                } label: {
                    Label("Capture Settings", systemImage: "camera.aperture")
                }

                NavigationLink {
                    DeviceInfoView()
                } label: {
                    Label("Device Info", systemImage: "info.circle")
                }
            }

            Section("Device") {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(capabilities.deviceName)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Chip")
                    Spacer()
                    Text(capabilities.iPhoneModel.chipName)
                        .foregroundStyle(.secondary)
                }
            }

            Section("App Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Tavi")
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
