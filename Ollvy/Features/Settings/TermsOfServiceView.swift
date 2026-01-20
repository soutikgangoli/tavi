//
//  TermsOfServiceView.swift
//  Ollvy
//
//  Terms of Service displayed in-app (India-compliant)
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
                    Text("Welcome to Ollvy! These Terms of Service govern your use of the Ollvy mobile application. These Terms comply with the Information Technology Act, 2000, Consumer Protection Act, 2019, and other applicable laws of India.")
                        .font(AppFont.bodySecondary)
                        .foregroundColor(Designs.Colors.textSecondary)

                    // Sections
                    termsSection(
                        number: "1",
                        title: "Acceptance of Terms",
                        content: """
                        By accessing or using Ollvy, you confirm that:

                        • You are at least 18 years of age, or if between 13-18 years, you have parental/guardian consent
                        • You are a resident of India or accessing from a jurisdiction where such use is permitted
                        • You have the legal capacity to enter into these Terms
                        • You will comply with all applicable laws and regulations of India
                        """
                    )

                    termsSection(
                        number: "2",
                        title: "Description of Service",
                        content: """
                        Ollvy is a skin analysis application that uses your device's TrueDepth camera to provide personalized skin insights:

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

                        Text("Ollvy is NOT a medical device registered with CDSCO. The App provides general skin analysis for informational purposes only. It does not diagnose, treat, cure, or prevent any disease. Always consult a qualified dermatologist registered with the Medical Council of India for medical advice.")
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
                        title: "User Obligations",
                        content: """
                        When using Ollvy, you agree to:

                        • Use the App only for personal skin analysis
                        • Comply with all applicable Indian laws
                        • Not reverse engineer, decompile, or disassemble the App
                        • Not use the App for any unlawful purpose
                        • Not misrepresent the App's analysis as medical diagnosis
                        • Not interfere with or disrupt the App's functionality
                        """
                    )

                    termsSection(
                        number: "5",
                        title: "Intellectual Property",
                        content: """
                        Ollvy and all its contents are protected by:

                        • Copyright Act, 1957 (India)
                        • Trade Marks Act, 1999 (India)
                        • Information Technology Act, 2000 (India)
                        • International intellectual property laws

                        You retain all rights to your personal data. Since all data is stored locally on your device, you maintain complete ownership and control.
                        """
                    )

                    // Privacy Highlight
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.green)

                            Text("Privacy & Data (DPDPA 2023 Compliant)")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                            privacyPoint("All facial data processed and stored locally on your device")
                            privacyPoint("No facial images transmitted to any server")
                            privacyPoint("No account or registration required")
                            privacyPoint("Delete your data at any time")
                            privacyPoint("Compliant with Digital Personal Data Protection Act, 2023")
                        }
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    termsSection(
                        number: "6",
                        title: "Disclaimer of Warranties",
                        content: """
                        THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND.

                        We do not warrant that:
                        • The App will meet your specific requirements
                        • The App will be uninterrupted or error-free
                        • Results will be accurate or reliable
                        • Any errors will be corrected

                        Note: Your statutory rights under Consumer Protection Act, 2019 are not affected.
                        """
                    )

                    termsSection(
                        number: "7",
                        title: "Limitation of Liability",
                        content: """
                        To the maximum extent permitted by Indian law, Ollvy shall not be liable for:

                        • Any indirect, incidental, or consequential damages
                        • Loss of profits, data, or goodwill
                        • Damages from your use of the App
                        • Medical decisions based on the App's analysis

                        Your rights under Consumer Protection Act, 2019 remain unaffected.
                        """
                    )

                    termsSection(
                        number: "8",
                        title: "Dispute Resolution",
                        content: """
                        Governing Law: Laws of India

                        Jurisdiction: Courts in Gurugram, Haryana, India

                        Before legal proceedings, please:
                        1. Contact care@ollvy.com
                        2. Contact care@ollvy.com (response within 15 days)

                        You may also approach Consumer Forums under Consumer Protection Act, 2019.
                        """
                    )

                    termsSection(
                        number: "9",
                        title: "Modifications to Terms",
                        content: """
                        We may modify these Terms at any time. When we make changes:

                        • The "Last Updated" date will be revised
                        • Material changes will be communicated via app updates
                        • Continued use constitutes acceptance

                        If you disagree, please stop using the App.
                        """
                    )

                    termsSection(
                        number: "10",
                        title: "Termination",
                        content: """
                        We may terminate access for breach of these Terms.

                        Upon termination:
                        • Your right to use the App ceases immediately
                        • All data on your device remains under your control
                        • You may uninstall the App at any time
                        """
                    )

                    // Grievance Officer Section
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.app(size: 20))
                                .foregroundColor(Designs.Colors.primary)

                            Text("Grievance Officer")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("As per IT Act, 2000 and DPDPA 2023:")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)

                        VStack(alignment: .leading, spacing: Designs.Spacing.xs) {
                            Text("Email: care@ollvy.com")
                                .font(AppFont.bodySecondary)
                            Text("Response: Within 24 hours")
                                .font(AppFont.bodySecondary)
                            Text("Resolution: Within 15 days")
                                .font(AppFont.bodySecondary)
                        }
                        .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    termsSection(
                        number: "11",
                        title: "Apple App Store Terms",
                        content: """
                        If you downloaded from the Apple App Store:

                        • These Terms are between you and Ollvy, not Apple
                        • Apple has no obligation for maintenance or support
                        • Apple is not responsible for product warranties
                        • Apple is a third-party beneficiary of these Terms
                        """
                    )

                    termsSection(
                        number: "12",
                        title: "Contact Information",
                        content: """
                        General Support: care@ollvy.com
                        Grievances: care@ollvy.com
                        App Store: Visit Ollvy on App Store > App Support
                        """
                    )

                    // Footer
                    VStack(spacing: Designs.Spacing.md) {
                        Divider()

                        Text("By using Ollvy, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service in accordance with Indian law.")
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
