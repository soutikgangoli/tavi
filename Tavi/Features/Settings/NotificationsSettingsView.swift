//
//  NotificationsSettingsView.swift
//  Tavi
//
//  Notification preferences and permissions management
//  Created on 2025-01-10
//

import SwiftUI
import UserNotifications

public struct NotificationsSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("scanRemindersEnabled") private var scanRemindersEnabled = false
    @AppStorage("challengeNotificationsEnabled") private var challengeNotificationsEnabled = true
    @AppStorage("achievementNotificationsEnabled") private var achievementNotificationsEnabled = true
    @AppStorage("progressReportsEnabled") private var progressReportsEnabled = true
    @AppStorage("scanReminderTime") private var scanReminderTimeData: Data = {
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
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                        HStack(spacing: HeadspaceDesign.Spacing.md) {
                            Image(systemName: permissionIcon)
                                .font(.system(size: 24))
                                .foregroundColor(permissionColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(permissionTitle)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                                Text(permissionSubtitle)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            }
                        }

                        if notificationPermissionStatus != .authorized {
                            Button {
                                requestNotificationPermission()
                            } label: {
                                Text("Enable Notifications")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(HeadspaceDesign.Colors.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.top, HeadspaceDesign.Spacing.sm)
                        }
                    }
                    .padding(.vertical, HeadspaceDesign.Spacing.sm)
                } header: {
                    Text("Notification Permissions")
                }

                // Scan reminders
                Section {
                    Toggle(isOn: $scanRemindersEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan Reminders")
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Text("Get reminded to scan regularly")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Text("Get notified about challenge milestones")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Text("Get notified when you unlock achievements")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)
                }

                // Progress reports
                Section {
                    Toggle(isOn: $progressReportsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Progress Reports")
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Text("Receive weekly summaries of your skin progress")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                    }
                    .disabled(notificationPermissionStatus != .authorized)
                } header: {
                    Text("Progress Tracking")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
            return HeadspaceDesign.Colors.primary
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
            return "Allow Tavi to send you helpful reminders and updates"
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
