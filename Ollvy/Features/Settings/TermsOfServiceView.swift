//
//  TermsOfServiceView.swift
//  Ollvy
//
//  Terms of Service displayed in-app
//  Created on 2026-01-15
//

import SwiftUI

public struct TermsOfServiceView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("Terms of Service")
                            .font(AppFont.pageTitle)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Last Updated: January 15, 2026")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.bottom, Designs.Spacing.md)

                    // Introduction
                    Text("Welcome to Ollvy! These Terms of Service govern your use of the Ollvy mobile application. By downloading, installing, or using Ollvy, you agree to be bound by these Terms.")
                        .font(AppFont.bodySecondary)
                        .foregroundColor(Designs.Colors.textSecondary)

                    // Sections
                    termsSection(
                        number: "1",
                        title: "Acceptance of Terms",
                        content: """
                        By accessing or using Ollvy, you confirm that:

                        • You are at least 13 years of age
                        • You have the legal capacity to enter into these Terms
                        • You will comply with all applicable laws and regulations
                        • You understand and accept these Terms in their entirety
                        """
                    )

                    termsSection(
                        number: "2",
                        title: "Description of Service",
                        content: """
                        Ollvy is a skin analysis application that uses your device's TrueDepth camera to provide personalized skin insights. The App offers:

                        • 3D Facial Scanning using Apple's TrueDepth technology
                        • Skin Analysis of various characteristics including texture, tone, and other metrics
                        • Progress Tracking to monitor changes over time
                        • Personalized Insights based on analysis
                        • Export Functionality as PDF reports
                        """
                    )

                    // Medical Disclaimer - Highlighted
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.orange)

                            Text("Important Medical Disclaimer")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("Ollvy is NOT a medical device. The App provides general skin analysis for informational and educational purposes only. It does not diagnose, treat, cure, or prevent any disease or medical condition. Always consult a qualified dermatologist or healthcare professional for medical advice.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    termsSection(
                        number: "3",
                        title: "Device Requirements",
                        content: """
                        To use Ollvy, you must have:

                        • An iPhone X or newer model with TrueDepth camera
                        • iOS 18.0 or later
                        • Sufficient storage space for the App and saved scan data
                        • Camera permissions granted to the App

                        Ollvy will not function on devices without TrueDepth camera capability.
                        """
                    )

                    termsSection(
                        number: "4",
                        title: "User Conduct",
                        content: """
                        When using Ollvy, you agree to:

                        • Use the App only for its intended purpose of personal skin analysis
                        • Provide accurate information when using the App
                        • Not attempt to reverse engineer, decompile, or disassemble the App
                        • Not use the App for any unlawful purpose
                        • Not attempt to gain unauthorized access to any portion of the App
                        • Not interfere with or disrupt the App's functionality
                        """
                    )

                    termsSection(
                        number: "5",
                        title: "Intellectual Property Rights",
                        content: """
                        Ollvy and all its contents, features, and functionality are owned by Ollvy and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.

                        You retain all rights to your personal data, including your facial scans and analysis results. Since all data is stored locally on your device and never transmitted to our servers, you maintain complete ownership and control of your content.
                        """
                    )

                    // Privacy Highlight
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.green)

                            Text("Privacy & Data")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                            privacyPoint("All facial data is processed and stored locally on your device")
                            privacyPoint("No facial images or scan results are transmitted to any server")
                            privacyPoint("No account or registration is required")
                            privacyPoint("You can delete your data at any time")
                        }
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    termsSection(
                        number: "6",
                        title: "Disclaimer of Warranties",
                        content: """
                        THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.

                        We do not warrant that:
                        • The App will meet your specific requirements
                        • The App will be uninterrupted, timely, secure, or error-free
                        • The results obtained from using the App will be accurate or reliable
                        • Any errors in the App will be corrected
                        """
                    )

                    termsSection(
                        number: "7",
                        title: "Limitation of Liability",
                        content: """
                        To the maximum extent permitted by applicable law, Ollvy shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to:

                        • Any loss of profits, data, use, goodwill, or other intangible losses
                        • Any damages resulting from your access to or use of the App
                        • Any damages resulting from errors or omissions in the App's content or analysis
                        """
                    )

                    termsSection(
                        number: "8",
                        title: "Indemnification",
                        content: """
                        You agree to defend, indemnify, and hold harmless Ollvy, its affiliates, and service providers from and against any claims, liabilities, damages, losses, or expenses arising out of:

                        • Your violation of these Terms
                        • Your use of the App
                        • Your violation of any third-party rights
                        """
                    )

                    termsSection(
                        number: "9",
                        title: "Modifications to Terms",
                        content: """
                        We reserve the right to modify these Terms at any time. When we make changes:

                        • The "Last Updated" date will be revised
                        • Material changes may be communicated through app updates
                        • Your continued use of the App after changes constitutes acceptance
                        """
                    )

                    termsSection(
                        number: "10",
                        title: "Termination",
                        content: """
                        We may terminate or suspend your access to the App immediately, without prior notice, for any reason including breach of these Terms.

                        Upon termination:
                        • Your right to use the App will immediately cease
                        • You may delete the App from your device
                        • All data stored locally on your device remains under your control
                        """
                    )

                    termsSection(
                        number: "11",
                        title: "Governing Law",
                        content: """
                        These Terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions. You agree to submit to the exclusive jurisdiction of the courts located in Bangalore, Karnataka, India.
                        """
                    )

                    termsSection(
                        number: "12",
                        title: "Apple-Specific Terms",
                        content: """
                        If you downloaded the App from the Apple App Store:

                        • These Terms are between you and Ollvy only, not Apple Inc.
                        • Apple has no obligation to furnish maintenance or support services
                        • Apple is not responsible for any product warranties
                        • Apple is not responsible for addressing any claims relating to the App
                        • Apple is a third-party beneficiary of these Terms
                        """
                    )

                    termsSection(
                        number: "13",
                        title: "Contact Information",
                        content: """
                        If you have any questions about these Terms of Service, please contact us:

                        Email: support@ollvy.app
                        """
                    )

                    // Footer
                    VStack(spacing: Designs.Spacing.md) {
                        Divider()

                        Text("By using Ollvy, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.")
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
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Section Builder

    private func termsSection(number: String, title: String, content: String) -> some View {
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
    TermsOfServiceView()
}
