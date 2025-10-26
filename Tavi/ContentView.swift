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
            Section("Features") {
                NavigationLink {
                    ResultsHistoryView()
                } label: {
                    Label("Analysis History", systemImage: "clock.arrow.circlepath")
                }

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
