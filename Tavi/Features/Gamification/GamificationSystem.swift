//
//  GamificationSystem.swift
//  Tavi
//
//  Streaks, achievements, challenges, and rewards to keep users engaged
//  Created on 2025-10-28.
//

import Foundation
import SwiftUI

// MARK: - Glow Challenge

/// 30-day glow challenge to build habit
public struct GlowChallenge: Codable, Identifiable {
    public let id: UUID
    let startDate: Date
    let goalDays: Int                     // Usually 30
    let checkIns: [Date]                  // Days user scanned
    let baselineGlowScore: Int            // Starting score
    let currentGlowScore: Int             // Latest score
    let isActive: Bool
    let completedDate: Date?

    var daysCompleted: Int {
        checkIns.count
    }

    var daysRemaining: Int {
        max(0, goalDays - daysCompleted)
    }

    var progressPercentage: Double {
        Double(daysCompleted) / Double(goalDays) * 100
    }

    var glowImprovement: Int {
        currentGlowScore - baselineGlowScore
    }

    var isCompleted: Bool {
        daysCompleted >= goalDays
    }

    var nextMilestone: ChallengeMilestone? {
        ChallengeMilestone.allMilestones.first { daysCompleted < $0.days }
    }

    public init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        goalDays: Int = 30,
        checkIns: [Date] = [],
        baselineGlowScore: Int,
        currentGlowScore: Int? = nil,
        isActive: Bool = true,
        completedDate: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.goalDays = goalDays
        self.checkIns = checkIns
        self.baselineGlowScore = baselineGlowScore
        self.currentGlowScore = currentGlowScore ?? baselineGlowScore
        self.isActive = isActive
        self.completedDate = completedDate
    }
}

/// Milestones within challenge
public struct ChallengeMilestone {
    let days: Int
    let title: String
    let iconName: String  // SF Symbol name
    let reward: String

    static let allMilestones: [ChallengeMilestone] = [
        ChallengeMilestone(days: 1, title: "First Scan", iconName: "leaf.fill", reward: "You've started your journey!"),
        ChallengeMilestone(days: 3, title: "3-Day Streak", iconName: "flame.fill", reward: "Building the habit!"),
        ChallengeMilestone(days: 7, title: "One Week", iconName: "star.fill", reward: "One week strong!"),
        ChallengeMilestone(days: 14, title: "Two Weeks", iconName: "bolt.fill", reward: "Halfway there!"),
        ChallengeMilestone(days: 21, title: "Three Weeks", iconName: "rocket.fill", reward: "Habit formed!"),
        ChallengeMilestone(days: 30, title: "30-Day Glow", iconName: "trophy.fill", reward: "Challenge Complete!"),
    ]
}

// MARK: - Streak System

/// Daily streak tracking
public struct GlowStreak: Codable {
    var currentStreak: Int                // Days in a row
    var longestStreak: Int                // Best streak ever
    var lastScanDate: Date?               // Last scan
    var totalScans: Int                   // All-time scans

    var isActiveToday: Bool {
        guard let last = lastScanDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    var streakIconName: String {
        switch currentStreak {
        case 0:
            return "zzz"
        case 1...2:
            return "leaf.fill"
        case 3...6:
            return "flame.fill"
        case 7...13:
            return "star.fill"
        case 14...29:
            return "bolt.fill"
        default:
            return "trophy.fill"
        }
    }

    var streakMessage: String {
        switch currentStreak {
        case 0:
            return "Start your streak today!"
        case 1:
            return "Great start! Come back tomorrow!"
        case 2:
            return "Two days! Keep it going!"
        case 3...6:
            return "\(currentStreak) day streak! You're on fire!"
        case 7...13:
            return "One week+ streak! Amazing!"
        case 14...29:
            return "\(currentStreak) days! You're unstoppable!"
        default:
            return "\(currentStreak) day streak! Legendary!"
        }
    }

    mutating func recordScan(date: Date = Date()) {
        totalScans += 1

        guard let last = lastScanDate else {
            // First scan ever
            currentStreak = 1
            longestStreak = 1
            lastScanDate = date
            return
        }

        let calendar = Calendar.current
        let daysSinceLastScan = calendar.dateComponents([.day], from: last, to: date).day ?? 0

        if daysSinceLastScan == 0 {
            // Same day, don't increment streak
            return
        } else if daysSinceLastScan == 1 {
            // Consecutive day!
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
        } else {
            // Streak broken
            currentStreak = 1
        }

        lastScanDate = date
    }

    public init() {
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastScanDate = nil
        self.totalScans = 0
    }

    public init(currentStreak: Int, longestStreak: Int, lastScanDate: Date?, totalScans: Int) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastScanDate = lastScanDate
        self.totalScans = totalScans
    }
}

// MARK: - Achievements

/// Unlockable achievements
public struct Achievement: Codable, Identifiable {
    public let id: String
    let title: String
    let description: String
    let iconName: String  // SF Symbol name
    let category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?

    static let allAchievements: [Achievement] = [
        // Scanning achievements
        Achievement(
            id: "first_scan",
            title: "First Scan",
            description: "Complete your first skin scan",
            iconName: "leaf.fill",
            category: .scanning,
            isUnlocked: false
        ),
        Achievement(
            id: "scan_10",
            title: "Regular User",
            description: "Complete 10 scans",
            iconName: "star.fill",
            category: .scanning,
            isUnlocked: false
        ),
        Achievement(
            id: "scan_50",
            title: "Skin Expert",
            description: "Complete 50 scans",
            iconName: "trophy.fill",
            category: .scanning,
            isUnlocked: false
        ),

        // Streak achievements
        Achievement(
            id: "streak_3",
            title: "On Fire",
            description: "Maintain a 3-day streak",
            iconName: "flame.fill",
            category: .streaks,
            isUnlocked: false
        ),
        Achievement(
            id: "streak_7",
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            iconName: "bolt.fill",
            category: .streaks,
            isUnlocked: false
        ),
        Achievement(
            id: "streak_30",
            title: "Dedication Master",
            description: "Maintain a 30-day streak",
            iconName: "trophy.fill",
            category: .streaks,
            isUnlocked: false
        ),

        // Improvement achievements
        Achievement(
            id: "glow_up_10",
            title: "Glow Up",
            description: "Improve Skin Health Index by 10 points",
            iconName: "sparkles",
            category: .improvement,
            isUnlocked: false
        ),
        Achievement(
            id: "glow_up_25",
            title: "Transformation",
            description: "Improve Skin Health Index by 25 points",
            iconName: "star.circle.fill",
            category: .improvement,
            isUnlocked: false
        ),
        Achievement(
            id: "glow_90",
            title: "Radiant Skin",
            description: "Achieve a Skin Health Index of 90+",
            iconName: "sparkle",
            category: .improvement,
            isUnlocked: false
        ),

        // Challenge achievements
        Achievement(
            id: "challenge_complete",
            title: "30-Day Glow Champion",
            description: "Complete the 30-day glow challenge",
            iconName: "medal.fill",
            category: .challenges,
            isUnlocked: false
        ),
    ]
}

public enum AchievementCategory: String, Codable {
    case scanning = "Scanning"
    case streaks = "Streaks"
    case improvement = "Improvement"
    case challenges = "Challenges"
}

// MARK: - Gamification Manager

public class GamificationManager {
    public static let shared = GamificationManager()

    private let challengeKey = "currentGlowChallenge"
    private let streakKey = "glowStreak"
    private let achievementsKey = "unlockedAchievements"

    private init() {}

    // MARK: - Challenge

    public func getCurrentChallenge() -> GlowChallenge? {
        guard let data = UserDefaults.standard.data(forKey: challengeKey) else {
            return nil
        }

        do {
            let challenge = try JSONDecoder().decode(GlowChallenge.self, from: data)
            return challenge.isActive ? challenge : nil
        } catch {
            AppLogger.gamification.error("Failed to decode current challenge: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_decode_challenge"])
            return nil
        }
    }

    public func startNewChallenge(baselineGlowScore: Int) -> GlowChallenge {
        let challenge = GlowChallenge(baselineGlowScore: baselineGlowScore)
        saveChallenge(challenge)
        return challenge
    }

    public func recordChallengeCheckIn(glowScore: Int) {
        guard let challenge = getCurrentChallenge() else { return }

        // Create updated challenge with new check-in
        var newCheckIns = challenge.checkIns
        let today = Calendar.current.startOfDay(for: Date())

        // Only add check-in if not already recorded today
        if !newCheckIns.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            newCheckIns.append(today)
        }

        // Create new challenge with updated values
        let updatedChallenge = GlowChallenge(
            id: challenge.id,
            startDate: challenge.startDate,
            goalDays: challenge.goalDays,
            checkIns: newCheckIns,
            baselineGlowScore: challenge.baselineGlowScore,
            currentGlowScore: glowScore,
            isActive: challenge.isActive,
            completedDate: newCheckIns.count >= challenge.goalDays ? Date() : challenge.completedDate
        )

        saveChallenge(updatedChallenge)
    }

    private func saveChallenge(_ challenge: GlowChallenge) {
        do {
            let data = try JSONEncoder().encode(challenge)
            UserDefaults.standard.set(data, forKey: challengeKey)
        } catch {
            AppLogger.gamification.error("Failed to encode challenge: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_challenge"])
        }
    }

    // MARK: - Streak

    public func getStreak() -> GlowStreak {
        if let data = UserDefaults.standard.data(forKey: streakKey) {
            do {
                let streak = try JSONDecoder().decode(GlowStreak.self, from: data)
                return streak
            } catch {
                AppLogger.gamification.error("Failed to decode streak: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_decode_streak"])
            }
        }
        return GlowStreak()
    }

    public func recordScan() -> GlowStreak {
        var streak = getStreak()
        streak.recordScan()
        saveStreak(streak)
        return streak
    }

    private func saveStreak(_ streak: GlowStreak) {
        do {
            let data = try JSONEncoder().encode(streak)
            UserDefaults.standard.set(data, forKey: streakKey)
        } catch {
            AppLogger.gamification.error("Failed to encode streak: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_streak"])
        }
    }

    // MARK: - Achievements

    public func getAchievements() -> [Achievement] {
        if let data = UserDefaults.standard.data(forKey: achievementsKey) {
            do {
                let achievements = try JSONDecoder().decode([Achievement].self, from: data)
                return achievements
            } catch {
                AppLogger.gamification.error("Failed to decode achievements: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_decode_achievements"])
            }
        }
        return Achievement.allAchievements
    }

    public func checkAndUnlockAchievements(
        totalScans: Int,
        currentStreak: Int,
        glowScore: Int,
        glowImprovement: Int,
        challengeComplete: Bool
    ) -> [Achievement] {
        var achievements = getAchievements()
        var newlyUnlocked: [Achievement] = []

        for i in 0..<achievements.count {
            if achievements[i].isUnlocked { continue }

            let shouldUnlock: Bool
            switch achievements[i].id {
            case "first_scan": shouldUnlock = totalScans >= 1
            case "scan_10": shouldUnlock = totalScans >= 10
            case "scan_50": shouldUnlock = totalScans >= 50
            case "streak_3": shouldUnlock = currentStreak >= 3
            case "streak_7": shouldUnlock = currentStreak >= 7
            case "streak_30": shouldUnlock = currentStreak >= 30
            case "glow_up_10": shouldUnlock = glowImprovement >= 10
            case "glow_up_25": shouldUnlock = glowImprovement >= 25
            case "glow_90": shouldUnlock = glowScore >= 90
            case "challenge_complete": shouldUnlock = challengeComplete
            default: shouldUnlock = false
            }

            if shouldUnlock {
                achievements[i].isUnlocked = true
                achievements[i].unlockedDate = Date()
                newlyUnlocked.append(achievements[i])
            }
        }

        saveAchievements(achievements)
        return newlyUnlocked
    }

    private func saveAchievements(_ achievements: [Achievement]) {
        do {
            let data = try JSONEncoder().encode(achievements)
            UserDefaults.standard.set(data, forKey: achievementsKey)
        } catch {
            AppLogger.gamification.error("Failed to encode achievements: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_achievements"])
        }
    }
}
