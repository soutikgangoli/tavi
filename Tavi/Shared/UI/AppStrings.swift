//
//  AppStrings.swift
//  Tavi
//
//  Centralized string constants for the entire app.
//  Change strings here to update text throughout the app.
//  This also prepares the app for future localization (i18n).
//

import Foundation

/// Centralized string constants - change text in ONE place
/// To localize: Replace string values with NSLocalizedString calls
public enum AppStrings {

    // MARK: - Common Button Labels

    public enum Buttons {
        public static let done = "Done"
        public static let cancel = "Cancel"
        public static let delete = "Delete"
        public static let save = "Save"
        public static let ok = "OK"
        public static let close = "Close"
        public static let skip = "Skip"
        public static let next = "Next"
        public static let back = "Back"
        public static let tryAgain = "Try Again"
        public static let retry = "Retry"
        public static let getStarted = "Get Started"
        public static let continueButton = "Continue"
        public static let learnMore = "Learn More"
        public static let share = "Share"
        public static let export = "Export"
        public static let refresh = "Refresh"
    }

    // MARK: - Scan Actions

    public enum Scan {
        public static let startScan = "Start Scan"
        public static let resumeScan = "Resume Scan"
        public static let cancelScan = "Cancel Scan"
        public static let scanAgain = "Scan Again"
        public static let newScan = "New Scan"
        public static let continueAnyway = "Continue Anyway"
        public static let discardScan = "Discard Scan"
        public static let keepScanning = "Keep Scanning"
    }

    // MARK: - Navigation Titles

    public enum Titles {
        public static let home = "Home"
        public static let settings = "Settings"
        public static let faceScan3D = "3D Face Scan"
        public static let analysisResults = "Analysis Results"
        public static let analysisHistory = "Analysis History"
        public static let skinAnalysis = "Skin Analysis"
        public static let skinMetrics3D = "3D Skin Metrics"
        public static let heatmapAnalysis = "Heatmap Analysis"
        public static let skinScores = "Skin Analysis Scores"
        public static let privacyData = "Privacy & Data"
        public static let about = "About"
        public static let deviceInfo = "Device Info"
        public static let captureSettings = "Capture Settings"
        public static let notifications = "Notifications"
        public static let dataBackups = "Data Backups"
        public static let performanceDiagnostics = "Performance Diagnostics"
        public static let achievements = "Achievements"
        public static let challenges = "Challenges"
        public static let insights = "Insights"
        public static let stats = "Stats"
    }

    // MARK: - Section Headers

    public enum Sections {
        public static let scanSettings = "Scan Settings"
        public static let lightingValidation = "Lighting Validation"
        public static let legal = "Legal"
        public static let onboarding = "Onboarding"
        public static let developer = "Developer"
        public static let dataManagement = "Data Management"
        public static let yourData = "Your Data"
        public static let storageInfo = "Storage Information"
        public static let dataPortability = "Data Portability"
        public static let skinHealth = "Skin Health"
        public static let agingIndicators = "Aging Indicators"
        public static let additionalIndicators = "Additional Indicators"
    }

    // MARK: - Empty States

    public enum EmptyStates {
        public static let noScansYet = "No scans yet"
        public static let noScansInRange = "No scans in this time range"
        public static let noAnalysisYet = "No Analysis Yet"
        public static let notEnoughData = "Not enough data yet"
        public static let notEnoughDataInRange = "Not enough data in selected time range"
        public static let noAchievements = "No achievements yet"
        public static let noChallenges = "No challenges available"

        public static let noScansDescription = "Complete your first skin analysis to see your results here"
        public static let tryDifferentRange = "Try selecting a different time range or complete a new scan."
    }

    // MARK: - Error Messages

    public enum Errors {
        public static let somethingWentWrong = "Something went wrong"
        public static let unableToLoad = "Unable to load your data. Please try again."
        public static let unableToLoadHistory = "Unable to load your scan history. Please try again later."
        public static let unableToLoadRecentScans = "Unable to load recent scans. Please try again later."
        public static let unableToLoadResults = "Unable to Load Results"
        public static let unableToLoadSharingOptions = "Unable to load sharing options"
        public static let sessionNotFound = "Session Not Found"
        public static let sessionNotFoundDescription = "This session may have been deleted or is no longer available."
        public static let oops = "Oops!"
    }

    // MARK: - Confirmation Dialogs

    public enum Confirmations {
        public static let deleteSessionTitle = "Delete Analysis"
        public static let deleteSessionMessage = "Are you sure you want to delete this analysis session?"
        public static let cancelScanTitle = "Cancel Scan?"
        public static let cancelScanMessage = "Are you sure you want to cancel? Your progress will be lost."
        public static let discardScanTitle = "Discard Scan?"
        public static let discardScanMessage = "Are you absolutely sure you want to discard your scan results?"
        public static let deleteAllDataTitle = "Delete All Data"
        public static let deleteAllDataMessage = "This action cannot be undone. All your scan history and data will be permanently deleted."
    }

    // MARK: - Processing States

    public enum Processing {
        public static let loading = "Loading..."
        public static let saving = "Saving..."
        public static let savingResults = "Saving Results..."
        public static let savingToHistory = "Please wait while we save your scan to history"
        public static let preparingScan = "Preparing scan"
        public static let analyzing = "Analyzing..."
        public static let processing = "Processing..."
        public static let almostDone = "Almost done..."
        public static let retrying = "Retrying..."
        public static let pleaseWait = "Please wait..."
    }

    // MARK: - Scan Guidance

    public enum ScanGuidance {
        public static let takeDeepBreath = "Take a deep breath"
        public static let holdStill = "Hold still"
        public static let lookStraight = "Look straight ahead"
        public static let turnLeft = "Turn left slowly"
        public static let turnRight = "Turn right slowly"
        public static let tiltUp = "Tilt up slightly"
        public static let tiltDown = "Tilt down slightly"
        public static let goodLighting = "Good lighting"
        public static let adjustLighting = "Adjust lighting"
        public static let moveCloser = "Move closer"
        public static let moveFarther = "Move farther"
        public static let faceDetected = "Face detected"
        public static let noFaceDetected = "No face detected"
        public static let scanComplete = "Scan Complete!"
    }

    // MARK: - Score Labels

    public enum ScoreLabels {
        public static let excellent = "Excellent"
        public static let good = "Good"
        public static let fair = "Fair"
        public static let needsImprovement = "Needs Improvement"
        public static let overall = "Overall"
        public static let average = "Average"
        public static let highest = "Highest"
        public static let lowest = "Lowest"
        public static let current = "Current"
        public static let previous = "Previous"
        public static let change = "Change"
    }

    // MARK: - Metric Names

    public enum Metrics {
        public static let overallScore = "Overall Score"
        public static let smoothness = "Smoothness"
        public static let hydration = "Hydration"
        public static let evenness = "Evenness"
        public static let pigmentation = "Pigmentation"
        public static let wrinkles = "Wrinkles"
        public static let elasticity = "Elasticity"
        public static let volume = "Volume"
        public static let pores = "Pores"
        public static let acne = "Acne"
        public static let redness = "Redness"
        public static let oilControl = "Oil Control"
        public static let sunProtection = "Sun Protection"
        public static let skinHealth = "Skin Health"
    }

    // MARK: - Time Ranges

    public enum TimeRanges {
        public static let today = "Today"
        public static let yesterday = "Yesterday"
        public static let thisWeek = "This Week"
        public static let thisMonth = "This Month"
        public static let oneMonth = "1M"
        public static let threeMonths = "3M"
        public static let sixMonths = "6M"
        public static let oneYear = "1Y"
        public static let allTime = "All Time"
    }

    // MARK: - Accessibility Labels

    public enum Accessibility {
        public static let closeButton = "Close"
        public static let backButton = "Go back"
        public static let shareButton = "Share results"
        public static let deleteButton = "Delete session"
        public static let infoButton = "More information"
        public static let settingsButton = "Open settings"
        public static let scanButton = "Start face scan"
        public static let settingsHint = "Opens app settings and preferences"
        public static let latestScanHint = "Tap to view complete results. Swipe left to delete."
        public static let skinHealthScore = "Skin Health Score"
    }

    // MARK: - Home Screen

    public enum Home {
        // Greetings
        public static let goodMorning = "Good morning"
        public static let goodAfternoon = "Good afternoon"
        public static let goodEvening = "Good evening"
        public static let readyToDiscover = "Ready to discover your skin's true health?"
        public static let trackYourJourney = "Track your skin health journey"

        // Status widgets
        public static let active = "Active"
        public static let startChallenge = "Start Challenge"
        public static let thirtyDayGlow = "30-Day Glow"
        public static let lastScan = "Last Scan"

        // Hero rings
        public static let overallHealth = "Overall Health"
        public static let viewAllMetrics = "View All Metrics"

        // Summary
        public static let overallScorePrefix = "Overall Score:"
        public static let baselineScan = "Baseline Scan"
        public static let latestScan = "Latest Scan"
        public static let greatProgress = "Great Progress!"
        public static let goodProgress = "Good Progress"
        public static let steadyProgress = "Steady Progress"
        public static let minorDecline = "Minor Decline"
        public static let needsAttention = "Needs Attention"
        public static let baselineScanDescription = "This is your baseline scan. Complete another scan to track progress and see improvements over time."
        public static let latestResultsReady = "Your latest scan results are ready to review."
        public static let metricsStable = "Your skin metrics are stable. Maintain your current routine."

        // First scan card
        public static let startYourFirstScan = "Start Your First Scan"
        public static let getCompleteAnalysis = "Get your complete skin health analysis in just 1 minute"
        public static let startYourScan = "Start Your Scan"
        public static let poweredByBiometrics = "Powered by Advanced Biometrics"
        public static let scienceBehindGlow = "The Science Behind Your Glow"
        public static let clinicalGradeImaging = "Advanced 3D imaging and AI skin analysis reveal details invisible to the naked eye."
        public static let whatYoullGet = "What You'll Get"
        public static let eightSkinMetrics = "8 Skin Health Metrics"
        public static let comprehensiveAnalysis = "Comprehensive analysis of your skin"
        public static let progressTracking = "Progress Tracking"
        public static let seeImprovements = "See improvements over time"
        public static let personalizedInsights = "Personalized Insights"
        public static let recommendationsTailored = "Get recommendations tailored to you"

        // Scan card
        public static let yourSkinHealthScore = "Your Skin Health Score"
        public static let lastScanned = "Last scanned"
        public static let viewDetails = "View details"
        public static let skinScore = "Skin Score"

        // Recent scans
        public static let recentScans = "Recent scans"
        public static func viewAllScans(_ count: Int) -> String {
            return "View All Scans (\(count))"
        }

        // Challenge
        public static let thirtyDayGlowChallenge = "30-Day Glow Challenge"
        public static let days = "days"
        public static func daysRemaining(_ count: Int) -> String {
            return "\(count) days remaining"
        }
        public static let glowImprovement = "Glow Improvement"
        public static let nextMilestone = "Next Milestone"

        // Tips
        public static let proTip = "Pro tip"
        public static let scanInBrightLight = "Scan in bright, natural light for best results"

        // Progress
        public static let yourProgress = "Your Progress"
        public static let progressOverTime = "Progress Over Time"
        public static let trend = "Trend"

        // Challenge progress
        public static func challengeDayProgress(_ day: Int) -> String {
            return "Day \(day) of 30"
        }
        public static func percentComplete(_ percent: Int) -> String {
            return "\(percent)% complete"
        }

        // Fallback storage
        public static let showingSavedResults = "Showing Saved Results"
        public static let scanHistoryTemporary = "Your scan history is temporarily stored. Results are saved and will sync when available."
        public static let tapStartNewScan = "Tap 'Start New Scan' below to see your latest results and track progress"

        // Score descriptions
        public static let excellentCondition = "Excellent condition"
        public static let veryGoodCondition = "Very good condition"
        public static let goodCondition = "Good condition"
        public static let needsImprovementCondition = "Needs improvement"
        public static let requiresAttention = "Requires attention"

        // Relative dates
        public static func daysAgo(_ count: Int) -> String {
            return count == 1 ? "1 day ago" : "\(count) days ago"
        }
        public static func weeksAgo(_ count: Int) -> String {
            return count == 1 ? "1 week ago" : "\(count) weeks ago"
        }
    }

    // MARK: - Settings Screen

    public enum Settings {
        // Section headers
        public static let scanSettings = "Scan Settings"
        public static let lightingValidation = "Lighting Validation"
        public static let appearance = "Appearance"
        public static let notifications = "Notifications"
        public static let privacy = "Privacy"
        public static let support = "Support"
        public static let legal = "Legal"
        public static let developer = "Developer"
        public static let dangerZone = "Danger Zone"

        // Scan settings
        public static let show3DFaceMesh = "Show 3D Face Mesh"
        public static let highQualityMode = "High Quality Mode"
        public static let hapticFeedback = "Haptic Feedback"
        public static let lightingValidationToggle = "Lighting Validation"
        public static let strictLighting = "Strict Lighting Mode"

        // Support
        public static let contactSupport = "Contact Support"
        public static let rateApp = "Rate Ollvy"
        public static let shareApp = "Share Ollvy"

        // Legal
        public static let privacyPolicy = "Privacy Policy"
        public static let termsOfService = "Terms of Service"

        // Developer
        public static let showDebugOverlay = "Show Debug Overlay"
        public static let resetOnboarding = "Reset Onboarding"
        public static let skipOnboarding = "Skip Onboarding"

        // Danger zone
        public static let deleteAllData = "Delete All Data"
    }

    // MARK: - About Screen

    public enum About {
        public static let appName = "Ollvy"
        public static let skinHealthAnalysis = "Skin Health Analysis"
        public static func version(_ version: String, build: String) -> String {
            return "Version \(version) (\(build))"
        }
        public static let about = "About"
        public static let developedWithLove = "Developed with SwiftUI"
        public static let allRightsReserved = "All rights reserved"
    }
}
