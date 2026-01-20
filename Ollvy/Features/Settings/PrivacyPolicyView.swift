//
//  PrivacyPolicyView.swift
//  Ollvy
//
//  Privacy Policy displayed in-app (India/DPDPA 2023 compliant)
//  Created on 2026-01-21
//

import SwiftUI

public struct PrivacyPolicyView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("Privacy Policy")
                            .font(AppFont.pageTitle)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Last Updated: January 21, 2026")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.bottom, Designs.Spacing.md)

                    // Privacy Highlight
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.app(size: 24))
                                .foregroundColor(.green)

                            Text("Your Privacy is Our Priority")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("Ollvy is designed with privacy at its core. All your facial scan data is processed and stored locally on your device. We never upload your face images to any server.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    // Introduction
                    Text("This Privacy Policy explains how Ollvy (\"we\", \"our\", or \"us\") collects, uses, and protects your information. This policy complies with the Digital Personal Data Protection Act, 2023 (DPDPA) and Information Technology Act, 2000 of India.")
                        .font(AppFont.bodySecondary)
                        .foregroundColor(Designs.Colors.textSecondary)

                    // Sections
                    policySection(
                        number: "1",
                        title: "Information We Collect",
                        content: """
                        Ollvy collects minimal data, all stored locally on your device:

                        • Facial Scan Data: 3D mesh geometry and texture analysis from TrueDepth camera scans
                        • Skin Metrics: Calculated analysis results (texture, tone, hydration estimates, etc.)
                        • App Preferences: Your settings and customization choices
                        • Session History: Records of your past scans for progress tracking

                        We do NOT collect:
                        • Your name, email, or contact information
                        • Location data
                        • Device identifiers for tracking
                        • Any data from other apps
                        """
                    )

                    policySection(
                        number: "2",
                        title: "How We Use Your Information",
                        content: """
                        Your data is used exclusively for:

                        • Performing Skin Analysis: Processing your facial scans to generate skin metrics
                        • Progress Tracking: Comparing scans over time to show changes
                        • Personalized Insights: Providing recommendations based on your results
                        • App Functionality: Saving your preferences and settings

                        We do NOT use your data for:
                        • Advertising or marketing
                        • Selling to third parties
                        • Training AI models
                        • Any purpose beyond the app's core functionality
                        """
                    )

                    // Key Privacy Point
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "iphone")
                                .font(.app(size: 20))
                                .foregroundColor(Designs.Colors.primary)

                            Text("100% On-Device Processing")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                            privacyPoint("All facial scans processed locally on your iPhone")
                            privacyPoint("No face images ever leave your device")
                            privacyPoint("No cloud storage or server uploads")
                            privacyPoint("No account or login required")
                            privacyPoint("Works completely offline")
                        }
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    policySection(
                        number: "3",
                        title: "Data Storage & Security",
                        content: """
                        Your data is protected by:

                        • Local Storage Only: All data stored in your device's secure app container
                        • iOS Security: Protected by Apple's built-in encryption and security features
                        • No Network Transmission: Facial data never transmitted over the internet
                        • App Sandbox: Data isolated from other apps on your device

                        Storage Location:
                        • Core Data database on your device
                        • Accessible only by the Ollvy app
                        • Deleted when you uninstall the app
                        """
                    )

                    policySection(
                        number: "4",
                        title: "Data Sharing",
                        content: """
                        We do NOT share your personal data with anyone.

                        • No Third-Party Analytics: We don't use external analytics services
                        • No Advertising Networks: No ad SDKs or tracking
                        • No Data Sales: We never sell your information
                        • No Cloud Sync: Your data stays on your device

                        The only data that leaves your device:
                        • Crash logs (anonymized, no personal data) - stored locally
                        • App performance metrics (anonymized) - stored locally
                        """
                    )

                    policySection(
                        number: "5",
                        title: "Your Rights (DPDPA 2023)",
                        content: """
                        Under the Digital Personal Data Protection Act, 2023, you have the right to:

                        • Access: View all your stored scan data within the app
                        • Correction: Edit your preferences and settings at any time
                        • Erasure: Delete all your data from Settings > Privacy > Delete All Data
                        • Portability: Export your data as JSON from Settings > Privacy > Export My Data
                        • Withdraw Consent: Stop using the app at any time; uninstalling removes all data

                        To exercise these rights, use the in-app controls or contact: care@ollvy.com
                        """
                    )

                    policySection(
                        number: "6",
                        title: "Camera & TrueDepth Usage",
                        content: """
                        Ollvy uses your device's TrueDepth camera system for facial scanning:

                        • Purpose: Capture 3D facial geometry for skin analysis
                        • Processing: All processing happens on-device using Apple's ARKit
                        • Storage: Processed mesh data stored locally; raw camera feed is not saved
                        • Not Biometric Auth: This is NOT used for authentication or identification

                        Camera access can be revoked anytime in iOS Settings > Ollvy > Camera.
                        """
                    )

                    policySection(
                        number: "7",
                        title: "Children's Privacy",
                        content: """
                        Ollvy is intended for users 13 years and older.

                        • Users aged 13-18 should have parental/guardian consent
                        • We do not knowingly collect data from children under 13
                        • If you believe a child under 13 has used the app, contact us to delete their data

                        Contact: care@ollvy.com
                        """
                    )

                    policySection(
                        number: "8",
                        title: "Changes to This Policy",
                        content: """
                        We may update this Privacy Policy from time to time:

                        • The "Last Updated" date will be revised
                        • Material changes will be communicated via app updates
                        • Continued use after changes constitutes acceptance
                        • Previous versions available upon request

                        We will never change our core commitment: your facial data stays on your device.
                        """
                    )

                    // Grievance Officer
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.app(size: 20))
                                .foregroundColor(Designs.Colors.primary)

                            Text("Grievance Officer (DPDPA 2023)")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("As required by Indian law:")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)

                        VStack(alignment: .leading, spacing: Designs.Spacing.xs) {
                            Text("Designation: Grievance Officer, Ollvy")
                                .font(AppFont.bodySecondary)
                            Text("Email: care@ollvy.com")
                                .font(AppFont.bodySecondary)
                            Text("Location: Gurugram, Haryana, India")
                                .font(AppFont.bodySecondary)
                            Text("Acknowledgment: Within 24 hours")
                                .font(AppFont.bodySecondary)
                            Text("Resolution: Within 15 days")
                                .font(AppFont.bodySecondary)
                        }
                        .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    policySection(
                        number: "9",
                        title: "Contact Us",
                        content: """
                        For privacy-related questions or concerns:

                        General Support: care@ollvy.com
                        Privacy/Grievances: care@ollvy.com

                        Response within 24 hours on business days.
                        """
                    )

                    // Footer
                    VStack(spacing: Designs.Spacing.md) {
                        Divider()

                        Text("By using Ollvy, you acknowledge that you have read and understood this Privacy Policy. Your continued use of the app constitutes acceptance of these terms.")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Designs.Spacing.lg)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle("Privacy Policy")
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
    }

    // MARK: - Section Builder

    private func policySection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack(spacing: Designs.Spacing.sm) {
                Text(number)
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.primary)
                    .frame(width: 24)

                Text(title)
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Text(content)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Designs.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    private func privacyPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Designs.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.app(size: 14))
                .foregroundColor(.green)

            Text(text)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
