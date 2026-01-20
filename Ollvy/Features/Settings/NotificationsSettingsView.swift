//
//  NotificationsSettingsView.swift
//  Ollvy
//
//  Notification preferences and permissions management
//  Created on 2025-01-10
//

import SwiftUI
import UserNotifications

public struct NotificationsSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppDefaultsKey.scanRemindersEnabled) private var scanRemindersEnabled = false
    @AppStorage(AppDefaultsKey.challengeNotificationsEnabled) private var challengeNotificationsEnabled = true
    @AppStorage(AppDefaultsKey.achievementNotificationsEnabled) private var achievementNotificationsEnabled = true
    @AppStorage(AppDefaultsKey.progressReportsEnabled) private var progressReportsEnabled = true
    @AppStorage(AppDefaultsKey.scanReminderTime) private var scanReminderTimeData: Data = {
        let calendar = Calendar.current
        let components = DateComponents(hour: 20, minute: 0) // 8:00 PM
        let date = calendar.date(from: components) ?? Date()
        return (try? JSONEncoder().encode(date)) ?? Data()
    }()

    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined

    private var scanReminderTime: Date {
        get {
            (try? JSONDecoder().decode(Date.self, from: scanReminderTimeData)) ?? Date()
        }
    }

    private func setScanReminderTime(_ newTime: Date) {
        scanReminderTimeData = (try? JSONEncoder().encode(newTime)) ?? Data()
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Permissions section
                Section {
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        HStack(spacing: Designs.Spacing.md) {
                            Image(systemName: permissionIcon)
                                .font(.app(size: 24))
                                .foregroundColor(permissionColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(permissionTitle)
                                    .font(AppFont.subheadingPrimary)
                                    .foregroundColor(Designs.Colors.textPrimary)

                                Text(permissionSubtitle)
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textSecondary)
                            }
                        }

                        if notificationPermissionStatus != .authorized {
                            Button {
                                requestNotificationPermission()
                            } label: {
                                Text("Enable Notifications")
                                    .font(AppFont.subheadingSecondary)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Designs.Colors.success)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.top, Designs.Spacing.sm)
                        }
                    }
                    .padding(.vertical, Designs.Spacing.sm)
                } header: {
                    Text("Notification Permissions")
                }

                // Scan reminders
                Section {
                    Toggle(isOn: $scanRemindersEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan Reminders")
                                .font(AppFont.bodyMedium)

                            Text("Get reminded to scan regularly")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)

                    if scanRemindersEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: Binding(
                                get: { scanReminderTime },
                                set: { setScanReminderTime($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .disabled(notificationPermissionStatus != .authorized)
                    }
                } header: {
                    Text("Scan Reminders")
                } footer: {
                    if scanRemindersEnabled {
                        Text("You'll receive a daily reminder at \(formatTime(scanReminderTime))")
                    }
                }

                // Challenge notifications
                Section {
                    Toggle(isOn: $challengeNotificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Challenge Updates")
                                .font(AppFont.bodyMedium)

                            Text("Get notified about challenge milestones")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)
                } header: {
                    Text("Gamification")
                }

                // Achievement notifications
                Section {
                    Toggle(isOn: $achievementNotificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Achievements")
                                .font(AppFont.bodyMedium)

                            Text("Get notified when you unlock achievements")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)
                }

                // Progress reports
                Section {
                    Toggle(isOn: $progressReportsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Progress Reports")
                                .font(AppFont.bodyMedium)

                            Text("Receive weekly summaries of your skin progress")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)
                } header: {
                    Text("Progress Tracking")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Designs.Colors.background)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Designs.Colors.primary)
                }
            }
            .toolbarBackground(Designs.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkNotificationPermissionStatus()
        }
    }

    // MARK: - Helpers

    private var permissionIcon: String {
        switch notificationPermissionStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        default:
            return "bell.fill"
        }
    }

    private var permissionColor: Color {
        switch notificationPermissionStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        default:
            return Designs.Colors.success
        }
    }

    private var permissionTitle: String {
        switch notificationPermissionStatus {
        case .authorized:
            return "Notifications Enabled"
        case .denied:
            return "Notifications Disabled"
        default:
            return "Enable Notifications"
        }
    }

    private var permissionSubtitle: String {
        switch notificationPermissionStatus {
        case .authorized:
            return "You'll receive notifications based on your preferences below"
        case .denied:
            return "Please enable notifications in Settings to receive reminders"
        default:
            return "Allow Ollvy to send you helpful reminders and updates"
        }
    }

    private func checkNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationPermissionStatus = .authorized
                } else {
                    notificationPermissionStatus = .denied
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NotificationsSettingsView()
}
