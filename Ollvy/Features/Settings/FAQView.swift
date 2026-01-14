//
//  FAQView.swift
//  Ollvy
//
//  Frequently Asked Questions displayed in-app (India-compliant)
//  Created on 2026-01-15
//

import SwiftUI

public struct FAQView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("Frequently Asked Questions")
                            .font(AppFont.pageTitle)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Everything you need to know about Ollvy")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.bottom, Designs.Spacing.md)

                    // Getting Started Section
                    faqSection(title: "Getting Started", icon: "play.circle.fill") {
                        FAQItem(
                            question: "What is Ollvy?",
                            answer: "Ollvy is an AI-powered skin analysis app that uses your iPhone's TrueDepth camera (the same technology used for Face ID) to perform detailed 3D facial scans. The app analyzes various aspects of your skin including texture, tone, hydration indicators, and more."
                        )

                        FAQItem(
                            question: "Which devices are compatible?",
                            answer: "Ollvy requires an iPhone with a TrueDepth camera system. This includes iPhone X and all newer models (XS, XR, 11, 12, 13, 14, 15, 16 series). iPad models are not currently supported."
                        )

                        FAQItem(
                            question: "Do I need to create an account?",
                            answer: "No! Ollvy is designed with privacy in mind and does not require any account creation, registration, or sign-in. You can start using the app immediately after downloading. All your data stays on your device."
                        )
                    }

                    // Using Ollvy Section
                    faqSection(title: "Using Ollvy", icon: "camera.fill") {
                        FAQItem(
                            question: "How do I perform a skin scan?",
                            answer: """
                            1. Open Ollvy and tap "Start Scan"
                            2. Grant camera permission when prompted
                            3. Position your face within the on-screen guide
                            4. Follow the prompts for proper lighting and positioning
                            5. Hold steady for about 10 seconds
                            6. View your results immediately after
                            """
                        )

                        FAQItem(
                            question: "What are the best conditions for scanning?",
                            answer: """
                            For the most accurate results:
                            • Use natural, even lighting
                            • Remove makeup and cleanse your face
                            • Hold your phone 12-18 inches from your face
                            • Keep your phone and head still
                            • Pull back hair from your face
                            • Remove glasses
                            """
                        )

                        FAQItem(
                            question: "How often should I scan?",
                            answer: "We recommend scanning once daily or every few days to track progress effectively. For the best comparison, scan at the same time of day with similar lighting conditions."
                        )

                        FAQItem(
                            question: "What metrics does Ollvy analyze?",
                            answer: """
                            Ollvy analyzes multiple aspects including:
                            • Skin Texture - Surface smoothness
                            • Skin Tone - Color evenness
                            • Hydration Indicators - Moisture signs
                            • Pore Appearance - Visibility and distribution
                            • Redness - Sensitivity areas
                            • Fine Lines - Visible lines and wrinkles
                            • Glow/Radiance - Overall luminosity
                            """
                        )
                    }

                    // Privacy & Security Section
                    faqSection(title: "Privacy & Security", icon: "lock.shield.fill") {
                        FAQItem(
                            question: "Is my facial data safe?",
                            answer: """
                            Yes, absolutely! Ollvy is built with a privacy-first approach:
                            • All facial scans are processed entirely on your device
                            • Your face data is never uploaded to any server
                            • No cloud storage - everything stays on your iPhone
                            • No account required - no personal information collected
                            """
                        )

                        FAQItem(
                            question: "Does Ollvy send my data to servers?",
                            answer: "No. Your facial scans, images, and analysis results never leave your device. The only data that may be transmitted is anonymized crash reports (if a technical error occurs), which contain no facial data or personal information."
                        )

                        FAQItem(
                            question: "Can I delete my data?",
                            answer: """
                            Yes, you have complete control:
                            • Delete individual scans by swiping left in your history
                            • Delete all data from Settings > Privacy > Delete All Data
                            • Uninstalling the app deletes all data permanently
                            """
                        )

                        FAQItem(
                            question: "Does Ollvy use Face ID?",
                            answer: "Ollvy uses the same TrueDepth camera hardware that powers Face ID, but it does NOT access or interact with your Face ID data. The app performs its own separate facial scanning for skin analysis purposes only."
                        )
                    }

                    // Results & Analysis Section
                    faqSection(title: "Results & Analysis", icon: "chart.bar.fill") {
                        FAQItem(
                            question: "How accurate is the analysis?",
                            answer: """
                            Ollvy uses advanced AI algorithms combined with 3D depth sensing. Please note:
                            • Results are intended for general awareness and tracking
                            • Accuracy can vary based on lighting and positioning
                            • Results are NOT medical diagnoses
                            • For medical concerns, always consult a dermatologist
                            """
                        )

                        FAQItem(
                            question: "Can I export my results?",
                            answer: "Yes! You can export your scan results as a professional PDF report. Open any scan result, tap the Share button, and select 'Export as PDF'."
                        )

                        FAQItem(
                            question: "What do the scores mean?",
                            answer: """
                            Each metric is scored 0-100:
                            • 80-100: Excellent
                            • 60-79: Good - Above average
                            • 40-59: Average - Typical range
                            • 20-39: Below Average
                            • 0-19: Needs Attention

                            These scores are for tracking, not medical assessment.
                            """
                        )

                        FAQItem(
                            question: "Is Ollvy a medical device?",
                            answer: "No, Ollvy is NOT a medical device registered with CDSCO (Central Drugs Standard Control Organisation). It provides general skin analysis for informational purposes only. It does not diagnose, treat, cure, or prevent any disease. If you have concerns about your skin, please consult a qualified dermatologist registered with the Medical Council of India."
                        )
                    }

                    // Troubleshooting Section
                    faqSection(title: "Troubleshooting", icon: "wrench.and.screwdriver.fill") {
                        FAQItem(
                            question: "The app says my device is not compatible",
                            answer: "Ollvy requires a TrueDepth camera, available only on iPhone X and newer. Older iPhones (8, 7, 6s, SE 1st gen) do not have TrueDepth cameras. Unfortunately, there is no workaround for devices without this hardware."
                        )

                        FAQItem(
                            question: "The scan keeps failing. How can I fix this?",
                            answer: """
                            Try these steps:
                            • Improve lighting - use bright, even light
                            • Clean the front camera and sensors
                            • Remove glasses and pull back hair
                            • Hold the phone 12-18 inches from your face
                            • Keep your phone and head still
                            • Restart the app
                            • Restart your phone if issues persist
                            """
                        )

                        FAQItem(
                            question: "Camera permission was denied. How do I enable it?",
                            answer: """
                            To enable camera access:
                            1. Open your iPhone's Settings app
                            2. Scroll down and tap Ollvy
                            3. Toggle Camera to ON (green)
                            4. Return to Ollvy and try again
                            """
                        )

                        FAQItem(
                            question: "The app is running slowly or crashing",
                            answer: """
                            If you're experiencing issues:
                            • Free up storage (need at least 1GB free)
                            • Close other apps
                            • Restart your iPhone
                            • Update iOS to the latest version
                            • Reinstall Ollvy (note: this deletes saved scans)
                            """
                        )
                    }

                    // Account & Data Section
                    faqSection(title: "Account & Data", icon: "person.circle.fill") {
                        FAQItem(
                            question: "Can I transfer my data to a new phone?",
                            answer: """
                            Yes! Your Ollvy data will transfer automatically if you:
                            • Use iCloud Backup and restore on your new device
                            • Use Quick Start to transfer directly between iPhones
                            • Use iTunes/Finder backup and restore
                            """
                        )

                        FAQItem(
                            question: "Is Ollvy free to use?",
                            answer: "Yes, Ollvy is currently free to download and use with all features available at no cost."
                        )

                        FAQItem(
                            question: "How do I contact support?",
                            answer: "You can reach us at support@ollvy.app. We typically respond within 24-48 hours."
                        )
                    }

                    // Legal & Privacy (India) Section
                    faqSection(title: "Legal & Privacy (India)", icon: "building.columns.fill") {
                        FAQItem(
                            question: "What Indian laws does Ollvy comply with?",
                            answer: """
                            Ollvy complies with:
                            • Digital Personal Data Protection Act, 2023 (DPDPA)
                            • Information Technology Act, 2000
                            • IT (SPDI) Rules, 2011
                            • Consumer Protection Act, 2019
                            • Consumer Protection (E-Commerce) Rules, 2020
                            """
                        )

                        FAQItem(
                            question: "What are my rights under DPDPA 2023?",
                            answer: """
                            As a Data Principal, you have:
                            • Right to Access your data
                            • Right to Correction of data
                            • Right to Erasure (deletion)
                            • Right to Data Portability (export)
                            • Right to Withdraw Consent
                            • Right to Grievance Redressal
                            """
                        )

                        FAQItem(
                            question: "Who is the Grievance Officer?",
                            answer: """
                            As required by Indian law:

                            Email: grievance@ollvy.app
                            Response: Within 24 hours
                            Resolution: Within 15 days

                            You may also approach Consumer Forums under Consumer Protection Act, 2019.
                            """
                        )

                        FAQItem(
                            question: "Is my biometric data safe under Indian law?",
                            answer: "Yes. Under Indian law, biometric data (including facial geometry) is classified as Sensitive Personal Data. Ollvy processes this data 100% on your device - it never leaves your phone. We comply with all IT (SPDI) Rules, 2011 security requirements."
                        )

                        FAQItem(
                            question: "Which courts have jurisdiction?",
                            answer: "Any disputes are subject to the exclusive jurisdiction of courts in Bangalore, Karnataka, India. You also have the right to approach Consumer Disputes Redressal Forums at District/State/National level."
                        )
                    }

                    // Contact Section
                    VStack(spacing: Designs.Spacing.md) {
                        Divider()

                        VStack(spacing: Designs.Spacing.sm) {
                            Text("Still have questions?")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Button {
                                if let url = URL(string: "mailto:support@ollvy.app") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Contact Support")
                                }
                                .font(AppFont.bodyMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, Designs.Spacing.xl)
                                .padding(.vertical, Designs.Spacing.md)
                                .background(Designs.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                            }
                        }
                    }
                    .padding(.top, Designs.Spacing.lg)
                    .frame(maxWidth: .infinity)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle("FAQ")
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

    @ViewBuilder
    private func faqSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack(spacing: Designs.Spacing.sm) {
                Image(systemName: icon)
                    .font(.app(size: 20))
                    .foregroundColor(Designs.Colors.primary)

                Text(title)
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }
            .padding(.bottom, Designs.Spacing.xs)

            content()
        }
    }
}

// MARK: - FAQ Item Component

struct FAQItem: View {
    let question: String
    let answer: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: Designs.Spacing.md) {
                    Text(question)
                        .font(AppFont.subheadingPrimary)
                        .foregroundColor(Designs.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundColor(Designs.Colors.textTertiary)
                }
                .padding(Designs.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(answer)
                    .font(AppFont.bodySecondary)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Designs.Spacing.md)
                    .padding(.bottom, Designs.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }
}

#Preview {
    FAQView()
}
