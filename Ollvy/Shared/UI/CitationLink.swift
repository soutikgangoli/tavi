//
//  CitationLink.swift
//  Ollvy
//
//  Inline citation system for scientific references
//

import SwiftUI

/// Scientific citation keys for recommendations
public enum CitationKey: String, CaseIterable, Sendable {
    case texture = "Setaro2001"
    case pigmentation = "Weatherall1992"
    case wrinkles = "Batisse2002"
    case hydration = "Rawlings2004"
    case blemish = "Gollnick2003"
    case pores = "Pierard2000"
    case redness = "Wilkin2002"
    case sunDamage = "Gilchrest2013"

    /// Numeric code for inline display [1], [2], etc.
    public var shortCode: String {
        switch self {
        case .texture: return "1"
        case .pigmentation: return "2"
        case .wrinkles: return "3"
        case .hydration: return "4"
        case .blemish: return "5"
        case .pores: return "6"
        case .redness: return "7"
        case .sunDamage: return "8"
        }
    }

    /// Full citation for reference list
    public var fullCitation: String {
        switch self {
        case .texture:
            return "Setaro M, Sparavigna A. Quantification of erythema using digital camera and computer-based colour image analysis. Skin Research and Technology. 2001;7(2):94-97."
        case .pigmentation:
            return "Weatherall IL, Coombs BD. Skin color measurements in terms of CIELAB color space values. Journal of Investigative Dermatology. 1992;99(4):468-473."
        case .wrinkles:
            return "Batisse D, Bazin R, Baldeweck T, et al. Influence of age on the wrinkling capacities of skin. Skin Research and Technology. 2002;8(3):148-154."
        case .hydration:
            return "Rawlings AV, Harding CR. Moisturization and skin barrier function. Dermatologic Therapy. 2004;17(s1):43-48."
        case .blemish:
            return "Gollnick H, Cunliffe W, Berson D, et al. Management of acne: a report from a Global Alliance. Journal of the American Academy of Dermatology. 2003;49(1):S1-S37."
        case .pores:
            return "Pierard GE, Pierard-Franchimont C, Marks R, et al. EEMCO guidance for the in vivo assessment of skin greasiness. Skin Pharmacology and Applied Skin Physiology. 2000;13(6):372-389."
        case .redness:
            return "Wilkin J, Dahl M, Detmar M, et al. Standard classification of rosacea: Report of the National Rosacea Society Expert Committee. Journal of the American Academy of Dermatology. 2002;46(4):584-587."
        case .sunDamage:
            return "Gilchrest BA. Photoaging. Journal of Investigative Dermatology. 2013;133(E1):E2-E6."
        }
    }

    /// Short description of what this citation supports
    public var topic: String {
        switch self {
        case .texture: return "Skin Texture Measurement"
        case .pigmentation: return "Skin Color Analysis"
        case .wrinkles: return "Wrinkle Assessment"
        case .hydration: return "Skin Hydration"
        case .blemish: return "Blemish Management"
        case .pores: return "Pore Assessment"
        case .redness: return "Redness Classification"
        case .sunDamage: return "Sun Damage & Photoaging"
        }
    }
}

/// Inline citation link that opens a detail sheet
public struct CitationLink: View {
    let key: CitationKey
    @State private var showingDetail = false

    public init(key: CitationKey) {
        self.key = key
    }

    public var body: some View {
        Button {
            showingDetail = true
        } label: {
            Text("[\(key.shortCode)]")
                .font(.caption2)
                .foregroundColor(Designs.Colors.accent)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            CitationDetailView(key: key)
        }
    }
}

/// Detail view showing full citation
public struct CitationDetailView: View {
    let key: CitationKey
    @Environment(\.dismiss) private var dismiss

    public init(key: CitationKey) {
        self.key = key
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Topic header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reference [\(key.shortCode)]")
                            .font(.caption)
                            .foregroundColor(Designs.Colors.textTertiary)

                        Text(key.topic)
                            .font(.title2.bold())
                            .foregroundColor(Designs.Colors.textPrimary)
                    }

                    Divider()

                    // Full citation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Citation")
                            .font(.subheadline.bold())
                            .foregroundColor(Designs.Colors.textSecondary)

                        Text(key.fullCitation)
                            .font(.body)
                            .foregroundColor(Designs.Colors.textPrimary)
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Designs.Colors.background)
            .navigationTitle("Scientific Reference")
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
}

/// View showing all citations
public struct AllCitationsView: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationView {
            List {
                ForEach(CitationKey.allCases, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("[\(key.shortCode)]")
                                .font(.caption.bold())
                                .foregroundColor(Designs.Colors.accent)

                            Text(key.topic)
                                .font(.subheadline.bold())
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text(key.fullCitation)
                            .font(.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Scientific References")
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
}

#Preview("Citation Link") {
    HStack {
        Text("Skin texture analysis")
        CitationLink(key: .texture)
    }
    .padding()
}

#Preview("All Citations") {
    AllCitationsView()
}
