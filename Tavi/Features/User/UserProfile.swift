//
//  UserProfile.swift
//  Tavi
//
//  User profile model for personalized recommendations
//  Stores age, skin type, goals, concerns
//

import Foundation

/// User profile for personalized analysis
public struct UserProfile: Codable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // User identification
    var name: String?

    // Demographics
    var age: Int?
    var gender: Gender?
    var skinTone: SkinTone?

    // Skin info
    var skinType: SkinType?
    var skinConcerns: Set<SkinConcern>
    var skinGoals: Set<SkinGoal>

    // Lifestyle
    var lifestyleFactors: LifestyleFactors

    // Preferences
    var preferredProducts: Set<ProductCategory>
    var budget: BudgetLevel?

    public init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.skinConcerns = []
        self.skinGoals = []
        self.preferredProducts = []
        self.lifestyleFactors = LifestyleFactors()
    }
}

// MARK: - Enums

public enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case preferNotToSay = "Prefer not to say"
}

public enum SkinTone: String, Codable, CaseIterable {
    case veryLight = "Very Light (I)"
    case light = "Light (II)"
    case medium = "Medium (III)"
    case mediumDark = "Medium-Dark (IV)"
    case dark = "Dark (V)"
    case veryDark = "Very Dark (VI)"

    var fitzpatrickScale: Int {
        switch self {
        case .veryLight: return 1
        case .light: return 2
        case .medium: return 3
        case .mediumDark: return 4
        case .dark: return 5
        case .veryDark: return 6
        }
    }
}

public enum SkinType: String, Codable, CaseIterable, Sendable {
    case dry = "Dry"
    case oily = "Oily"
    case combination = "Combination"
    case normal = "Normal"
    case sensitive = "Sensitive"
}

public enum SkinConcern: String, Codable, CaseIterable, Hashable {
    case wrinkles = "Wrinkles & Fine Lines"
    case darkCircles = "Dark Circles"
    case acne = "Acne"
    case dryness = "Dryness"
    case oiliness = "Oiliness"
    case largePores = "Large Pores"
    case darkSpots = "Dark Spots & Hyperpigmentation"
    case redness = "Redness & Sensitivity"
    case dullness = "Dullness"
    case sagging = "Sagging & Loss of Firmness"
}

public enum SkinGoal: String, Codable, CaseIterable, Hashable {
    case antiAging = "Anti-Aging"
    case brighten = "Brighten Skin"
    case evenTone = "Even Skin Tone"
    case hydrate = "Hydrate"
    case minimizePores = "Minimize Pores"
    case firmness = "Improve Firmness"
    case reduceWrinkles = "Reduce Wrinkles"
    case clearAcne = "Clear Acne"
    case soothe = "Soothe Sensitivity"
    case glow = "Achieve Glow"
}

public enum ProductCategory: String, Codable, CaseIterable, Hashable {
    case cleanser = "Cleanser"
    case moisturizer = "Moisturizer"
    case serum = "Serum"
    case sunscreen = "Sunscreen"
    case eyeCream = "Eye Cream"
    case mask = "Face Mask"
    case exfoliant = "Exfoliant"
    case retinol = "Retinol"
    case vitaminC = "Vitamin C"
    case niacinamide = "Niacinamide"
}

public enum BudgetLevel: String, Codable, CaseIterable {
    case budget = "Budget ($)"
    case moderate = "Moderate ($$)"
    case premium = "Premium ($$$)"
    case luxury = "Luxury ($$$$)"
}

public struct LifestyleFactors: Codable {
    var waterIntake: WaterIntake = .moderate
    var sleepQuality: SleepQuality = .good
    var stressLevel: StressLevel = .moderate
    var sunExposure: SunExposure = .moderate
    var smokingStatus: SmokingStatus = .nonSmoker
    var alcoholConsumption: AlcoholConsumption = .occasional
    var exerciseFrequency: ExerciseFrequency = .moderate

    public init() {}
}

public enum WaterIntake: String, Codable, CaseIterable {
    case low = "< 4 glasses/day"
    case moderate = "4-6 glasses/day"
    case good = "6-8 glasses/day"
    case excellent = "8+ glasses/day"
}

public enum SleepQuality: String, Codable, CaseIterable {
    case poor = "Poor (< 5 hours)"
    case fair = "Fair (5-6 hours)"
    case good = "Good (6-7 hours)"
    case excellent = "Excellent (7-8+ hours)"
}

public enum StressLevel: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

public enum SunExposure: String, Codable, CaseIterable {
    case minimal = "Minimal (indoors most of the time)"
    case moderate = "Moderate (some outdoor time)"
    case high = "High (frequent outdoor activities)"
}

public enum SmokingStatus: String, Codable, CaseIterable {
    case nonSmoker = "Non-smoker"
    case former = "Former smoker"
    case occasional = "Occasional smoker"
    case regular = "Regular smoker"
}

public enum AlcoholConsumption: String, Codable, CaseIterable {
    case none = "None"
    case occasional = "Occasional (1-2/week)"
    case moderate = "Moderate (3-4/week)"
    case frequent = "Frequent (5+/week)"
}

public enum ExerciseFrequency: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case light = "Light (1-2/week)"
    case moderate = "Moderate (3-4/week)"
    case active = "Active (5+/week)"
}

// MARK: - Profile Manager

public class UserProfileManager {
    public static let shared = UserProfileManager()

    private let profileKey = "userProfile"

    private init() {}

    // Load profile
    public func loadProfile() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: profileKey) {
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                return profile
            } catch {
                AppLogger.storage.error("Failed to decode user profile: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_decode_profile"])
            }
        }
        return UserProfile()  // New profile
    }

    // Save profile
    public func saveProfile(_ profile: UserProfile) {
        var updated = profile
        updated.updatedAt = Date()

        do {
            let data = try JSONEncoder().encode(updated)
            UserDefaults.standard.set(data, forKey: profileKey)
        } catch {
            AppLogger.storage.error("Failed to encode user profile: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_profile"])
        }
    }

    // Update specific fields with validation
    public func updateName(_ name: String) throws {
        let validation = InputValidator.validateName(name)
        guard validation.isValid else {
            throw NSError(
                domain: "UserProfileManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: validation.errorMessage ?? "Invalid name"]
            )
        }

        var profile = loadProfile()
        profile.name = name
        saveProfile(profile)
    }

    public func updateAge(_ age: Int) throws {
        let validation = InputValidator.validateAge(String(age))
        guard validation.isValid else {
            throw NSError(
                domain: "UserProfileManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: validation.errorMessage ?? "Invalid age"]
            )
        }

        var profile = loadProfile()
        profile.age = age
        saveProfile(profile)
    }

    public func updateSkinType(_ type: SkinType) {
        var profile = loadProfile()
        profile.skinType = type
        saveProfile(profile)
    }

    public func addConcern(_ concern: SkinConcern) {
        var profile = loadProfile()
        profile.skinConcerns.insert(concern)
        saveProfile(profile)
    }

    public func addGoal(_ goal: SkinGoal) {
        var profile = loadProfile()
        profile.skinGoals.insert(goal)
        saveProfile(profile)
    }
}
