//
//  InputValidator.swift
//  Tavi
//
//  Input validation utility for user forms
//  Fixes Issue #29: Adds validation to prevent bad data
//

import Foundation

/// Validation result with error message
public struct ValidationResult {
    public let isValid: Bool
    public let errorMessage: String?

    public static func valid() -> ValidationResult {
        return ValidationResult(isValid: true, errorMessage: nil)
    }

    public static func invalid(_ message: String) -> ValidationResult {
        return ValidationResult(isValid: false, errorMessage: message)
    }
}

/// Input validation utility
public struct InputValidator {

    // MARK: - Name Validation

    /// Validate user name
    /// - Parameter name: User's name
    /// - Returns: Validation result
    public static func validateName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Please enter your name")
        }

        if trimmed.count < 2 {
            return .invalid("Name must be at least 2 characters")
        }

        if trimmed.count > 50 {
            return .invalid("Name must be less than 50 characters")
        }

        // Check for valid characters (letters, spaces, hyphens, apostrophes)
        let validPattern = "^[a-zA-Z\\s'-]+$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", validPattern)
        if !predicate.evaluate(with: trimmed) {
            return .invalid("Name can only contain letters, spaces, hyphens, and apostrophes")
        }

        return .valid()
    }

    // MARK: - Age Validation

    /// Validate user age
    /// - Parameter ageString: Age as string
    /// - Returns: Validation result
    public static func validateAge(_ ageString: String) -> ValidationResult {
        let trimmed = ageString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Please enter your age")
        }

        guard let age = Int(trimmed) else {
            return .invalid("Please enter a valid age number")
        }

        if age < 13 {
            return .invalid("You must be at least 13 years old to use this app")
        }

        if age > 120 {
            return .invalid("Please enter a valid age")
        }

        return .valid()
    }

    // MARK: - Email Validation (if needed)

    /// Validate email address
    /// - Parameter email: Email address
    /// - Returns: Validation result
    public static func validateEmail(_ email: String) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Please enter your email address")
        }

        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)

        if !predicate.evaluate(with: trimmed) {
            return .invalid("Please enter a valid email address")
        }

        return .valid()
    }

    // MARK: - Generic Text Validation

    /// Validate generic text field
    /// - Parameters:
    ///   - text: Text to validate
    ///   - fieldName: Name of the field for error messages
    ///   - minLength: Minimum required length
    ///   - maxLength: Maximum allowed length
    /// - Returns: Validation result
    public static func validateText(
        _ text: String,
        fieldName: String,
        minLength: Int = 1,
        maxLength: Int = 500
    ) -> ValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Please enter \(fieldName)")
        }

        if trimmed.count < minLength {
            return .invalid("\(fieldName) must be at least \(minLength) character\(minLength > 1 ? "s" : "")")
        }

        if trimmed.count > maxLength {
            return .invalid("\(fieldName) must be less than \(maxLength) characters")
        }

        return .valid()
    }

    // MARK: - Numeric Validation

    /// Validate numeric input within range
    /// - Parameters:
    ///   - valueString: Value as string
    ///   - fieldName: Name of the field for error messages
    ///   - min: Minimum allowed value
    ///   - max: Maximum allowed value
    /// - Returns: Validation result
    public static func validateNumber(
        _ valueString: String,
        fieldName: String,
        min: Double,
        max: Double
    ) -> ValidationResult {
        let trimmed = valueString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid("Please enter \(fieldName)")
        }

        guard let value = Double(trimmed) else {
            return .invalid("Please enter a valid number for \(fieldName)")
        }

        if value < min {
            return .invalid("\(fieldName) must be at least \(min)")
        }

        if value > max {
            return .invalid("\(fieldName) must be at most \(max)")
        }

        return .valid()
    }

    // MARK: - Skin Type Validation

    /// Validate skin type selection
    /// - Parameter skinType: Selected skin type
    /// - Returns: Validation result
    public static func validateSkinType(_ skinType: String?) -> ValidationResult {
        guard let skinType = skinType, !skinType.isEmpty else {
            return .invalid("Please select your skin type")
        }

        let validTypes = ["Type I", "Type II", "Type III", "Type IV", "Type V", "Type VI"]
        if !validTypes.contains(skinType) {
            return .invalid("Please select a valid skin type")
        }

        return .valid()
    }

    // MARK: - Date Validation

    /// Validate date is not in future
    /// - Parameter date: Date to validate
    /// - Returns: Validation result
    public static func validatePastDate(_ date: Date, fieldName: String = "Date") -> ValidationResult {
        if date > Date() {
            return .invalid("\(fieldName) cannot be in the future")
        }

        return .valid()
    }

    /// Validate date is within reasonable range
    /// - Parameters:
    ///   - date: Date to validate
    ///   - yearsInPast: Maximum years in the past
    ///   - fieldName: Field name for error messages
    /// - Returns: Validation result
    public static func validateReasonableDate(
        _ date: Date,
        yearsInPast: Int = 120,
        fieldName: String = "Date"
    ) -> ValidationResult {
        let calendar = Calendar.current
        guard let minDate = calendar.date(byAdding: .year, value: -yearsInPast, to: Date()) else {
            return .invalid("Invalid date")
        }

        if date < minDate {
            return .invalid("\(fieldName) is too far in the past")
        }

        if date > Date() {
            return .invalid("\(fieldName) cannot be in the future")
        }

        return .valid()
    }
}
