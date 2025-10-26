//
//  DataModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation

// MARK: - Analysis Result
public struct AnalysisResult: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let metrics: [String: Double]

    public init(id: UUID = UUID(), timestamp: Date = Date(), metrics: [String: Double] = [:]) {
        self.id = id
        self.timestamp = timestamp
        self.metrics = metrics
    }
}

// MARK: - Capture Session
public struct CaptureSession: Identifiable, Codable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?

    public init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }
}
