//
//  ClinicalInfoView.swift
//  Ollvy
//
//  Expandable clinical breakdown explaining how each metric was calculated
//  Consumer-friendly presentation of scientific methodology
//  Created on 2025-10-29.
//

import SwiftUI

/// Clinical information breakdown view (expandable dropdown)
public struct ClinicalInfoView: View {
    let emotionalMetrics: EmotionalMetrics
    let clinicalMetrics: Face3DMetrics

    @State private var isExpanded = false

    public init(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) {
        self.emotionalMetrics = emotionalMetrics
        self.clinicalMetrics = clinicalMetrics
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "flask.fill")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("How We Analyze Your Appearance")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(AppFont.metricLabel)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(Designs.CornerRadius.medium)
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Scientific Methodology")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, Designs.Spacing.medium)

                    // Radiance breakdown - Pure luminosity measurement
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Radiance: \(emotionalMetrics.radiance)/100")
                                    .font(.headline)
                                    .foregroundColor(.yellow)
                                Text("(Skin brightness & light reflection)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("Why \(emotionalMetrics.radiance)?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Emotional summary - score dependent
                        Text(radianceEmotionalSummary(score: emotionalMetrics.radiance))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        // Calculation breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Component 1: Evenness (60% weight)
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Designs.Colors.primary.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("60% of Skin Tone Evenness")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(String(format: "%.1f", clinicalMetrics.globalPigmentationScore))")
                                            .font(.subheadline)
                                            .foregroundColor(.yellow)
                                            .fontWeight(.semibold)
                                    }

                                    // What we captured
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "camera.fill")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("Pigmentation Index: \(String(format: "%.2f", clinicalMetrics.globalPigmentationIndex))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "grid")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            let regionCount = String(clinicalMetrics.roiMetrics.count)
                                            Text("Analyzed \(regionCount) face regions (forehead, cheeks, nose, chin)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "ruler")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("Color variance in LAB space across \(String(format: "%.0f", clinicalMetrics.textureResolution.width))×\(String(format: "%.0f", clinicalMetrics.textureResolution.height))px texture")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        // Accuracy indicator
                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Visual texture pattern analysis")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Then normalized for your skin tone to ensure fairness")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Divider()

                            // Component 2: Shine (40% weight)
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Designs.Colors.primary.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("40% of Natural Shine")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(String(format: "%.1f", clinicalMetrics.globalSpecularScore ?? 50.0))")
                                            .font(.subheadline)
                                            .foregroundColor(.yellow)
                                            .fontWeight(.semibold)
                                    }

                                    // What we captured
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        if let specular = clinicalMetrics.globalSpecularProxy {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("Specular Reflection: \(String(format: "%.4f", specular))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            HStack {
                                                Image(systemName: "lightbulb.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("Bright pixel ratio (>200/255 brightness)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            HStack {
                                                Image(systemName: "checkmark.shield.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                                Text("Light reflection pattern observed")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .fontWeight(.medium)
                                            }
                                        } else {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                                Text("⚠️ Estimated - Specular data unavailable (using default 50)")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)
                                }
                            }

                            Divider()

                            // Final calculation
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Final Calculation:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    let finalScore = String(emotionalMetrics.radiance)
                                    Text("(\(String(format: "%.1f", clinicalMetrics.globalPigmentationScore)) × 0.6) + (\(String(format: "%.1f", clinicalMetrics.globalSpecularScore ?? 50.0)) × 0.4) = \(finalScore)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(Designs.Spacing.small)
                            .background(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.CornerRadius.small)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(Designs.CornerRadius.medium)
                    }

                    // Smoothness breakdown - WHY is it 82?
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("🧈")
                                .font(.title2)
                            Text("Smoothness: \(emotionalMetrics.smoothness)/100")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("Why \(emotionalMetrics.smoothness)?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Emotional summary - score dependent
                        Text(smoothnessEmotionalSummary(score: emotionalMetrics.smoothness))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Direct from roughness score
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Designs.Colors.info.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Inverted Roughness Score")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(String(format: "%.1f", clinicalMetrics.globalRoughnessScore))")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }

                                    // What we captured
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "camera.fill")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("Roughness Proxy: \(String(format: "%.4f", clinicalMetrics.globalRoughnessProxy))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "waveform")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("High-frequency texture energy via Laplacian filter")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "viewfinder")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            let vertexCountStr = String(clinicalMetrics.vertexCount)
                                            let triangleCountStr = String(clinicalMetrics.triangleCount)
                                            Text("Scanned \(vertexCountStr) vertices, \(triangleCountStr) triangles")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "grid")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            let regionCountStr = String(clinicalMetrics.roiMetrics.count)
                                            Text("Analyzed \(regionCountStr) regions for micro-texture patterns")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        // Accuracy indicator
                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Surface texture pattern assessment")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Algorithm: Identifies fine texture patterns using gradient analysis")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Divider()

                            // Final score
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Final Score:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Smoothness = Roughness Score = \(emotionalMetrics.smoothness)/100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(Lower roughness = Higher smoothness)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(Designs.Spacing.small)
                            .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.CornerRadius.small)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(Designs.CornerRadius.medium)
                    }

                    // Evenness breakdown - WHY is it 79?
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("🌟")
                                .font(.title2)
                            Text("Evenness: \(emotionalMetrics.evenness)/100")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Spacer()
                            Text("Why \(emotionalMetrics.evenness)?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Emotional summary - score dependent
                        Text(evennessEmotionalSummary(score: emotionalMetrics.evenness))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Pigmentation uniformity score
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.purple.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Pigmentation Uniformity")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(String(format: "%.1f", clinicalMetrics.globalPigmentationScore))")
                                            .font(.subheadline)
                                            .foregroundColor(.purple)
                                            .fontWeight(.semibold)
                                    }

                                    // What we captured
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "camera.fill")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("Pigmentation Index: \(String(format: "%.2f", clinicalMetrics.globalPigmentationIndex))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "camera.fill")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("Discoloration Index: \(String(format: "%.2f", clinicalMetrics.globalDiscolorationIndex))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "paintpalette")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            Text("LAB color space analysis (perceptually uniform)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        HStack {
                                            Image(systemName: "grid")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            let zoneCount = String(clinicalMetrics.roiMetrics.count)
                                            Text("Inter-regional variance across \(zoneCount) zones")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        // Accuracy indicator
                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Adjusted for skin tone variations")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Fairness: Scores normalized by your baseline skin tone to ensure equal assessment")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Divider()

                            // Final score
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Final Score:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Evenness = Pigmentation Score = \(emotionalMetrics.evenness)/100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("(Lower variance = Higher evenness)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(Designs.Spacing.small)
                            .background(Color.purple.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.CornerRadius.small)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(Designs.CornerRadius.medium)
                    }

                    // Youthfulness breakdown - WHY is it 75?
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("🌸")
                                .font(.title2)
                            Text("Youthfulness: \(emotionalMetrics.youthfulness)/100")
                                .font(.headline)
                                .foregroundColor(.pink)
                            Spacer()
                            Text("Why \(emotionalMetrics.youthfulness)?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Emotional summary - score dependent
                        Text(youthfulnessEmotionalSummary(score: emotionalMetrics.youthfulness))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Component 1: Smoothness
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.pink.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Texture Smoothness")
                                            .font(.subheadline)
                                        Spacer()
                                        let smoothnessValue = String(emotionalMetrics.smoothness)
                                        Text("\(smoothnessValue)")
                                            .font(.subheadline)
                                            .foregroundColor(.pink)
                                            .fontWeight(.semibold)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Based on smoothness analysis above")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)
                                }
                            }

                            Divider()

                            // Component 2: Wrinkle Assessment
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.pink.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Wrinkle Assessment")
                                            .font(.subheadline)
                                        Spacer()
                                        if let wrinkles = clinicalMetrics.wrinkleAnalysis {
                                            Text("\(String(format: "%.1f", wrinkles.overallScore))")
                                                .font(.subheadline)
                                                .foregroundColor(.pink)
                                                .fontWeight(.semibold)
                                        } else {
                                            Text("\(String(format: "%.1f", clinicalMetrics.globalRoughnessScore))")
                                                .font(.subheadline)
                                                .foregroundColor(.pink)
                                                .fontWeight(.semibold)
                                        }
                                    }

                                    // What we captured
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        if let wrinkles = clinicalMetrics.wrinkleAnalysis {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("Wrinkle Count: \(wrinkles.wrinkleCount) detected")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            HStack {
                                                Image(systemName: "ruler.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("Depth: \(wrinkles.wrinkleDepth.rawValue)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            HStack {
                                                Image(systemName: "waveform.path")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                let vertexCountForCurvature = String(clinicalMetrics.vertexCount)
                                                Text("3D curvature analysis on \(vertexCountForCurvature) vertices")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            // Accuracy warning
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                                Text("⚠️ Empirical - Depth scaling factor (0.00002) not clinically validated")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                                    .fontWeight(.medium)
                                            }
                                        } else {
                                            HStack {
                                                Image(systemName: "info.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("Using roughness score as proxy (wrinkle analysis not performed)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Note: Wrinkle visibility assessment is for cosmetic reference only")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .italic()
                                }
                            }

                            Divider()

                            // Final score
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.pink)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Final Score:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if let wrinkles = clinicalMetrics.wrinkleAnalysis {
                                        let smoothnessStr = String(emotionalMetrics.smoothness)
                                        let youthfulnessStr = String(emotionalMetrics.youthfulness)
                                        Text("Youthfulness ≈ (\(smoothnessStr) + \(String(format: "%.1f", wrinkles.overallScore))) / 2 = \(youthfulnessStr)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .font(.system(.body, design: .monospaced))
                                    } else {
                                        let youthfulnessStr = String(emotionalMetrics.youthfulness)
                                        Text("Youthfulness ≈ Smoothness = \(youthfulnessStr)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("(Better texture + Fewer wrinkles = More youthful)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(Designs.Spacing.small)
                            .background(Color.pink.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.CornerRadius.small)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(Designs.CornerRadius.medium)
                    }

                    // Freshness breakdown - WHY is it 81?
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("🌿")
                                .font(.title2)
                            Text("Freshness: \(emotionalMetrics.freshness)/100")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                            Text("Why \(emotionalMetrics.freshness)?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Emotional summary - score dependent
                        Text(freshnessEmotionalSummary(score: emotionalMetrics.freshness))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation:")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            // Component 1: Evenness (50% weight)
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Designs.ScoreColors.excellent.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("50% of Tone Evenness")
                                            .font(.subheadline)
                                        Spacer()
                                        let evennessValue = String(emotionalMetrics.evenness)
                                        Text("\(evennessValue)")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                            .fontWeight(.semibold)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Based on evenness analysis above")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Uniform pigmentation indicates well-hydrated skin")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Divider()

                            // Component 2: Smoothness (50% weight)
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Designs.ScoreColors.excellent.opacity(Designs.Opacity.medium))
                                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                                    .padding(.top, Designs.Spacing.tiny)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("50% of Texture Smoothness")
                                            .font(.subheadline)
                                        Spacer()
                                        let smoothnessValue2 = String(emotionalMetrics.smoothness)
                                        Text("\(smoothnessValue2)")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                            .fontWeight(.semibold)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("What we captured:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Based on smoothness analysis above")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .padding(Designs.Spacing.xSmall)
                                    .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                    .cornerRadius(Designs.CornerRadius.small)

                                    Text("Refined texture indicates optimal moisture levels")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Divider()

                            // Final calculation
                            HStack {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Final Calculation:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    let evennessStr = String(emotionalMetrics.evenness)
                                    let smoothnessStr = String(emotionalMetrics.smoothness)
                                    let freshnessStr = String(emotionalMetrics.freshness)
                                    Text("(\(evennessStr) × 0.5) + (\(smoothnessStr) × 0.5) = \(freshnessStr)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                    Text("Freshness serves as a proxy for hydration - we cannot measure moisture directly from 3D scans")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(Designs.Spacing.small)
                            .background(Designs.ScoreColors.excellent.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.CornerRadius.small)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(Designs.CornerRadius.medium)
                    }

                    // Confidence scores
                    confidenceSection

                }
                .padding()
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(Designs.CornerRadius.medium)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Emotional Summary Helpers

    /// Returns score-dependent emotional summary for Radiance (Physics-Based Luminosity)
    private func radianceEmotionalSummary(score: Int) -> String {
        switch score {
        case 80...100:
            return "Your skin is radiating beautifully! We analyzed how much light your skin reflects and found bright, natural luminosity. Your skin has that lit-from-within glow that catches the light perfectly."
        case 60...79:
            return "Your skin has decent radiance, but could be brighter. We analyzed your skin's light reflection and brightness levels. With proper exfoliation and hydration, you can boost that luminous quality."
        case 40...59:
            return "Your skin appears dull and needs brightening. Our luminosity analysis shows moderate light reflection. This can be improved with vitamin C, proper hydration, and regular exfoliation to reveal that natural brightness."
        default: // 0-39
            return "Your skin looks very dull and needs serious brightening. Our physics-based light analysis shows low luminosity. Focus on brightening serums (vitamin C, niacinamide), gentle exfoliation, and deep hydration to restore that natural radiance."
        }
    }

    /// Returns score-dependent emotional summary for Smoothness
    private func smoothnessEmotionalSummary(score: Int) -> String {
        switch score {
        case 80...100:
            return "Your skin texture is looking really refined! We checked how smooth your skin surface is by looking at all those tiny details. The smoother your texture, the softer and more polished your skin appears."
        case 60...79:
            return "Your skin texture is pretty good, but not quite silky smooth yet. We noticed some minor roughness in the texture. With consistent care, you can definitely get to that polished, refined feel."
        case 40...59:
            return "Your skin texture is showing some roughness that's worth addressing. We found noticeable texture irregularities. This is a great area to focus on to help your skin feel smoother and look more refined."
        default: // 0-39
            return "Your skin texture needs significant improvement. We detected quite a bit of roughness across your skin surface. Don't worry though—with the right skincare routine, you can work towards smoother, softer skin."
        }
    }

    /// Returns score-dependent emotional summary for Evenness
    private func evennessEmotionalSummary(score: Int) -> String {
        switch score {
        case 80...100:
            return "Your skin tone is beautifully balanced! We analyzed how consistent your color is across your whole face. The more even your tone, the more unified and flawless your complexion looks."
        case 60...79:
            return "Your skin tone is fairly consistent, but there are some areas with color variations. We noticed some unevenness across different parts of your face. Evening this out will give you a more unified complexion."
        case 40...59:
            return "Your skin tone shows noticeable unevenness that could be improved. We found significant color variations across your face. This is definitely something to work on for a more balanced, flawless look."
        default: // 0-39
            return "Your skin tone has considerable unevenness that needs attention. We detected major color inconsistencies across your face. With targeted skincare, you can work towards a more balanced complexion."
        }
    }

    /// Returns score-dependent emotional summary for Youthfulness
    private func youthfulnessEmotionalSummary(score: Int) -> String {
        switch score {
        case 80...100:
            return "Your skin is showing great vitality! We looked at how smooth and firm your skin appears, plus checked for any fine lines. Together, these tell us how youthful and resilient your skin is looking today."
        case 60...79:
            return "Your skin is holding up pretty well, but showing some early signs of aging. We noticed some fine lines and slight texture changes. These are normal, and with good care, you can maintain that youthful bounce."
        case 40...59:
            return "Your skin is showing visible signs of aging that could be addressed. We found noticeable lines and texture concerns. This is a key area where the right routine can help restore some of that youthful vitality."
        default: // 0-39
            return "Your skin is showing significant aging signs that need attention. We detected pronounced lines and texture issues. Don't be discouraged—targeted anti-aging care can help improve firmness and reduce visible aging."
        }
    }

    /// Returns score-dependent emotional summary for Freshness
    private func freshnessEmotionalSummary(score: Int) -> String {
        switch score {
        case 80...100:
            return "Your skin looks wonderfully hydrated and alive! We combined your skin tone evenness with your texture smoothness. When both are looking good, it means your skin is well-nourished and bouncy."
        case 60...79:
            return "Your skin looks decent, but could be more vibrant. We combined your tone evenness and texture smoothness, and they're showing your skin could use more hydration and nourishment to look truly fresh."
        case 40...59:
            return "Your skin is looking a bit tired and needs freshening up. Both your tone and texture are indicating that your skin could really benefit from better hydration and nourishment to bounce back."
        default: // 0-39
            return "Your skin is looking quite dull and needs serious hydration. We're seeing that both evenness and smoothness are low, which means your skin is really craving moisture and care to look alive again."
        }
    }

    // MARK: - Confidence Section

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                Text("Confidence Scores")
                    .font(.headline)
            }

            Text("How reliable are these measurements?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                if let pores = clinicalMetrics.poreAnalysis {
                    ConfidenceRow(metric: "Pore Analysis", confidence: pores.confidence)
                }
                if let acne = clinicalMetrics.acneAnalysis {
                    ConfidenceRow(metric: "Blemish Detection", confidence: acne.confidence)
                }
                if let wrinkles = clinicalMetrics.wrinkleAnalysis {
                    ConfidenceRow(metric: "Wrinkle Detection", confidence: wrinkles.confidence)
                }

                // Overall scan quality
                ConfidenceRow(metric: "Overall Scan Quality", confidence: clinicalMetrics.isHighQuality ? 90 : 60)
            }

            // Disclaimer
            Text("Note: Confidence scores reflect measurement reliability based on lighting, scan quality, and algorithm certainty.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(.top, 16)
    }
}

// MARK: - Supporting Views

/// Individual metric breakdown card
struct MetricBreakdownCard: View {
    let title: String
    let emoji: String
    let color: Color
    let formula: String
    let components: [(String, String, String)]  // (name, value, description)
    let methodology: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(emoji)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }

            // Formula
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text(formula)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(Designs.Spacing.xSmall)
            .background(color.opacity(Designs.Opacity.veryLight))
            .cornerRadius(Designs.CornerRadius.small)

            // Components
            VStack(alignment: .leading, spacing: 8) {
                ForEach(components.indices, id: \.self) { index in
                    let component = components[index]
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color.opacity(Designs.Opacity.medium))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(component.0)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(component.1)
                                    .font(.subheadline)
                                    .foregroundColor(color)
                                    .fontWeight(.semibold)
                            }
                            Text(component.2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Methodology
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .padding(.top, 2)
                Text(methodology)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Designs.Spacing.small)
            .background(Color(UIColor.quaternarySystemFill))
            .cornerRadius(Designs.CornerRadius.small)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(Designs.CornerRadius.medium)
    }
}

/// Confidence level row
struct ConfidenceRow: View {
    let metric: String
    let confidence: Float

    private var confidenceLevel: (String, Color) {
        switch confidence {
        case 80...100:
            return ("High", .green)
        case 60..<80:
            return ("Good", .blue)
        case 40..<60:
            return ("Moderate", .orange)
        default:
            return ("Low", .red)
        }
    }

    var body: some View {
        HStack {
            Text(metric)
                .font(.subheadline)
            Spacer()
            let confidenceInt = String(Int(confidence))
            Text("\(confidenceInt)%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(confidenceLevel.1)
            Text(confidenceLevel.0)
                .font(.caption)
                .padding(.horizontal, Designs.Spacing.xSmall)
                .padding(.vertical, 4)
                .background(confidenceLevel.1.opacity(Designs.Opacity.light))
                .foregroundColor(confidenceLevel.1)
                .cornerRadius(Designs.CornerRadius.tiny)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ClinicalInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            ClinicalInfoView(
                emotionalMetrics: previewEmotionalMetrics,
                clinicalMetrics: previewClinicalMetrics
            )
            .padding()
        }
    }

    static var previewEmotionalMetrics: EmotionalMetrics {
        EmotionalMetrics(
            skinAppearanceScore: 85,
            primaryInsight: "Your skin looks amazing today!",
            celebration: "Great starting point!",
            improvements: [],
            concerns: [],
            personalizedMessage: "Your skin is in great shape!",
            nextSteps: [],
            timeEstimate: "See results in 2-3 weeks",
            radiance: 88,
            smoothness: 82,
            evenness: 79,
            youthfulness: 75,
            freshness: 81,
            acneScore: 80,
            colorEvennessScore: 75,
            oilControlScore: 70,
            poreScore: 75
        )
    }

    static var previewClinicalMetrics: Face3DMetrics {
        Face3DMetrics(
            roiMetrics: [:],
            globalRoughnessProxy: 15.2,
            globalPigmentationIndex: 8.5,
            globalDiscolorationIndex: 12.3,
            globalSpecularProxy: 20.1,
            globalAverageLuminance: 128.4,
            globalRoughnessScore: 82.0,
            globalPigmentationScore: 79.0,
            globalDiscolorationScore: 75.0,
            globalSpecularScore: 70.0,
            overallScore: 78.5,
            scoreInterpretation: "Good",
            vertexCount: 12450,
            triangleCount: 24900,
            textureResolution: CGSize(width: 2048, height: 2048),
            processingTime: 3.4,
            textureQuality: "Excellent",
            lowConfidenceROIs: [],
            isHighQuality: true
        )
    }
}
#endif
