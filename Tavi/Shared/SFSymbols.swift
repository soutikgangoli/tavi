//
//  SFSymbols.swift
//  Tavi
//
//  Centralized SF Symbol names for the entire app.
//  Prevents typos and enables easy updates if Apple changes icon names.
//

import Foundation

/// Centralized SF Symbol names - type-safe icon references
/// Usage: Image(systemName: SFSymbol.checkmark)
enum SFSymbol {

    // MARK: - Navigation

    /// Chevron pointing right (>)
    static let chevronRight = "chevron.right"

    /// Chevron pointing left (<)
    static let chevronLeft = "chevron.left"

    /// Chevron pointing down (v)
    static let chevronDown = "chevron.down"

    /// Chevron pointing up (^)
    static let chevronUp = "chevron.up"

    /// Arrow pointing right
    static let arrowRight = "arrow.right"

    /// Arrow pointing up and right (external link style)
    static let arrowUpRight = "arrow.up.right"

    /// Arrow pointing up and right in a square
    static let arrowUpRightSquare = "arrow.up.right.square"

    /// Back arrow
    static let arrowLeft = "arrow.left"

    // MARK: - Status & Checkmarks

    /// Simple checkmark
    static let checkmark = "checkmark"

    /// Checkmark in a filled circle
    static let checkmarkCircleFill = "checkmark.circle.fill"

    /// Checkmark in a circle outline
    static let checkmarkCircle = "checkmark.circle"

    /// Checkmark on a shield (security/verified)
    static let checkmarkShieldFill = "checkmark.shield.fill"

    /// X mark (close/cancel)
    static let xmark = "xmark"

    /// X mark in a circle
    static let xmarkCircle = "xmark.circle"

    /// X mark in a filled circle
    static let xmarkCircleFill = "xmark.circle.fill"

    // MARK: - Warnings & Errors

    /// Exclamation mark in a triangle (warning)
    static let exclamationTriangle = "exclamationmark.triangle"

    /// Exclamation mark in a filled triangle
    static let exclamationTriangleFill = "exclamationmark.triangle.fill"

    /// Exclamation mark in a circle
    static let exclamationCircle = "exclamationmark.circle"

    /// Exclamation mark in a filled circle
    static let exclamationCircleFill = "exclamationmark.circle.fill"

    // MARK: - Actions

    /// Camera icon
    static let camera = "camera"

    /// Camera icon filled
    static let cameraFill = "camera.fill"

    /// Refresh/retry arrow
    static let arrowClockwise = "arrow.clockwise"

    /// Share icon (square with arrow up)
    static let squareAndArrowUp = "square.and.arrow.up"

    /// Download icon (square with arrow down)
    static let squareAndArrowDown = "square.and.arrow.down"

    /// Trash/delete icon
    static let trash = "trash"

    /// Trash filled
    static let trashFill = "trash.fill"

    /// Pencil/edit icon
    static let pencil = "pencil"

    /// Plus icon
    static let plus = "plus"

    /// Plus in a circle
    static let plusCircle = "plus.circle"

    /// Plus in a filled circle
    static let plusCircleFill = "plus.circle.fill"

    /// Minus icon
    static let minus = "minus"

    // MARK: - Features & Metrics

    /// Fire/flame icon (streaks, hot features)
    static let flame = "flame"

    /// Fire/flame filled
    static let flameFill = "flame.fill"

    /// Sparkles (beauty, glow)
    static let sparkles = "sparkles"

    /// Star icon
    static let star = "star"

    /// Star filled
    static let starFill = "star.fill"

    /// Lightbulb (tips, insights)
    static let lightbulb = "lightbulb"

    /// Lightbulb filled
    static let lightbulbFill = "lightbulb.fill"

    /// Trophy (achievements)
    static let trophy = "trophy"

    /// Trophy filled
    static let trophyFill = "trophy.fill"

    /// Heart (health, favorites)
    static let heart = "heart"

    /// Heart filled
    static let heartFill = "heart.fill"

    /// Face smiling
    static let faceSmiling = "face.smiling"

    /// Waveform path (analysis, data)
    static let waveformPath = "waveform.path"

    /// Equal sign in circle
    static let equalCircleFill = "equal.circle.fill"

    /// Chart/graph bar
    static let chartBar = "chart.bar"

    /// Chart bar filled
    static let chartBarFill = "chart.bar.fill"

    // MARK: - Information

    /// Info icon in circle
    static let infoCircle = "info.circle"

    /// Info icon in filled circle
    static let infoCircleFill = "info.circle.fill"

    /// Question mark in circle
    static let questionmarkCircle = "questionmark.circle"

    /// Question mark in filled circle
    static let questionmarkCircleFill = "questionmark.circle.fill"

    // MARK: - Settings & System

    /// Gear icon (settings)
    static let gear = "gear"

    /// Gear icon filled
    static let gearshapeFill = "gearshape.fill"

    /// Person icon
    static let person = "person"

    /// Person filled
    static let personFill = "person.fill"

    /// Person in circle
    static let personCircle = "person.circle"

    /// Person in filled circle
    static let personCircleFill = "person.circle.fill"

    /// Bell (notifications)
    static let bell = "bell"

    /// Bell filled
    static let bellFill = "bell.fill"

    /// Lock icon
    static let lock = "lock"

    /// Lock filled
    static let lockFill = "lock.fill"

    /// Shield icon
    static let shield = "shield"

    /// Shield filled
    static let shieldFill = "shield.fill"

    // MARK: - Time & Calendar

    /// Clock icon
    static let clock = "clock"

    /// Clock filled
    static let clockFill = "clock.fill"

    /// Calendar icon
    static let calendar = "calendar"

    /// Calendar filled
    static let calendarFill = "calendar.fill"

    // MARK: - Media & Display

    /// Photo/image icon
    static let photo = "photo"

    /// Photo filled
    static let photoFill = "photo.fill"

    /// Eye icon (visibility)
    static let eye = "eye"

    /// Eye filled
    static let eyeFill = "eye.fill"

    /// Eye with slash (hidden)
    static let eyeSlash = "eye.slash"

    /// Eye slash filled
    static let eyeSlashFill = "eye.slash.fill"

    // MARK: - Arrows & Direction

    /// Arrow up
    static let arrowUp = "arrow.up"

    /// Arrow down
    static let arrowDown = "arrow.down"

    /// Arrow up and down (sort)
    static let arrowUpArrowDown = "arrow.up.arrow.down"

    /// Circular arrows (sync/refresh)
    static let arrowTriangle2Circlepath = "arrow.triangle.2.circlepath"

    // MARK: - Face Scan Specific

    /// Face ID icon
    static let faceid = "faceid"

    /// Viewfinder (scan target)
    static let viewfinder = "viewfinder"

    /// Viewfinder with circle
    static let viewfinderCircle = "viewfinder.circle"

    /// Sun icon (lighting)
    static let sunMax = "sun.max"

    /// Sun filled
    static let sunMaxFill = "sun.max.fill"

    /// Sun min (low light)
    static let sunMin = "sun.min"

    /// Sun min filled
    static let sunMinFill = "sun.min.fill"
}
