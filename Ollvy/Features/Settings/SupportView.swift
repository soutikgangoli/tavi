//
//  SupportView.swift
//  Ollvy
//
//  In-app support and help center
//  Created on 2026-01-21
//

import SwiftUI
import MessageUI

public struct SupportView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showingMailComposer = false
    @State private var showingMailError = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("Help & Support")
                            .font(AppFont.pageTitle)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("We're here to help")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.bottom, Designs.Spacing.md)

                    // Contact Section
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "envelope.fill")
                                .font(.app(size: 20))
                                .foregroundColor(Designs.Colors.success)

                            Text("Contact Us")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("Have a question, feedback, or need help? Reach out to us!")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)

                        Button {
                            sendEmail()
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Email Support")
                                    .font(AppFont.bodyMedium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Designs.Spacing.md)
                            .background(Designs.Colors.success)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                        }

                        Text("care@ollvy.com")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    // FAQ Section
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.app(size: 20))
                                .foregroundColor(Designs.Colors.success)

                            Text("Frequently Asked Questions")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }
                    }
                    .padding(.top, Designs.Spacing.md)

                    faqItem(
                        question: "What devices support Ollvy?",
                        answer: "Ollvy requires iPhone X or newer with TrueDepth camera (Face ID hardware). This includes iPhone X, XS, XR, 11, 12, 13, 14, 15, 16 series and newer."
                    )

                    faqItem(
                        question: "Is my facial data safe?",
                        answer: "Yes! All your facial scan data is processed and stored locally on your device. We never upload your face images to any server. Your data stays 100% on your iPhone."
                    )

                    faqItem(
                        question: "How accurate is the skin analysis?",
                        answer: "Ollvy provides general skin insights using advanced 3D scanning technology. However, it is NOT a medical device and should not replace professional dermatological advice. Always consult a qualified dermatologist for medical concerns."
                    )

                    faqItem(
                        question: "Why does the scan need good lighting?",
                        answer: "Good lighting helps the TrueDepth camera capture accurate facial geometry and skin texture. Poor lighting can affect the quality of your scan results. Natural daylight or bright indoor lighting works best."
                    )

                    faqItem(
                        question: "How do I delete my data?",
                        answer: "Go to Settings > Privacy & Data > Delete All Data. This will permanently remove all your scans and analysis results from your device."
                    )

                    faqItem(
                        question: "Can I export my scan history?",
                        answer: "Yes! Go to Settings > Privacy & Data > Export My Data to download all your scan data as a JSON file."
                    )

                    faqItem(
                        question: "Why is my scan quality low?",
                        answer: "Scan quality can be affected by: poor lighting, moving during the scan, glasses or accessories on your face, or camera obstructions. Try scanning in bright, even lighting while holding still."
                    )

                    // Response Time
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "clock.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.orange)

                            Text("Response Time")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("We typically respond within 24 hours on business days. For urgent issues, please include \"URGENT\" in your email subject.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    // App Version Info
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("App Information")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        HStack {
                            Text("Version")
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                        .font(AppFont.bodySecondary)

                        HStack {
                            Text("Build")
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text(appBuild)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                        .font(AppFont.bodySecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Designs.Colors.success)
                }
            }
            .toolbarBackground(Designs.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Email Not Available", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
                Button("Copy Email") {
                    UIPasteboard.general.string = "care@ollvy.com"
                }
            } message: {
                Text("Mail is not configured on this device. You can email us directly at care@ollvy.com")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - FAQ Item

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
            Text(question)
                .font(AppFont.bodyMedium)
                .foregroundColor(Designs.Colors.textPrimary)

            Text(answer)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Designs.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    // MARK: - Email

    private func sendEmail() {
        let email = "care@ollvy.com"
        let subject = "Ollvy Support Request"
        let body = """


        ---
        App Version: \(appVersion) (\(appBuild))
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showingMailError = true
            }
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SupportView()
}
