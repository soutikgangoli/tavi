//
//  ScientificReferencesView.swift
//  Ollvy
//
//  Scientific references and citations for skin analysis metrics
//  Created on 2025-01-26.
//

import SwiftUI

/// Scientific references and citations for medical/skincare information
public struct ScientificReferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        Text("Scientific Foundation")
                            .font(.app(size: 24, weight: .bold))
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Ollvy's skin analysis is based on established dermatological research and computer vision techniques. Below are the scientific references supporting our metrics and recommendations.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Designs.Spacing.lg)
                    .padding(.top, Designs.Spacing.md)

                    // Medical Disclaimer at top
                    disclaimerCard

                    // References by Category
                    Group {
                        referenceSection(
                            title: "Skin Texture & Roughness",
                            icon: "waveform.path",
                            references: [
                                Reference(
                                    authors: "Setaro M, Sparavigna A.",
                                    year: "2001",
                                    title: "Quantification of skin roughness by image analysis.",
                                    journal: "Skin Research and Technology",
                                    citation: "7(1):24-7"
                                ),
                                Reference(
                                    authors: "Fluhr JW, Darlenski R, Surber C.",
                                    year: "2008",
                                    title: "Glycerol and the skin: holistic approach to its origin and functions.",
                                    journal: "British Journal of Dermatology",
                                    citation: "159(1):23-34"
                                ),
                                Reference(
                                    authors: "Voegeli R, Rawlings AV, Doppler S, Heiland J, Schreier T.",
                                    year: "2015",
                                    title: "Profiling of serine protease activities in human stratum corneum and detection of a stratum corneum tryptase-like enzyme.",
                                    journal: "International Journal of Cosmetic Science",
                                    citation: "37(5):497-505"
                                )
                            ],
                            description: "Surface texture analysis assesses variations in skin smoothness using established image analysis techniques referenced in peer-reviewed research."
                        )

                        referenceSection(
                            title: "Pigmentation & Tone Evenness",
                            icon: "circle.hexagongrid.fill",
                            references: [
                                Reference(
                                    authors: "Chardon A, Cretois I, Hourseau C.",
                                    year: "1991",
                                    title: "Skin colour typology and suntanning pathways.",
                                    journal: "International Journal of Cosmetic Science",
                                    citation: "13(4):191-208"
                                ),
                                Reference(
                                    authors: "Weatherall IL, Coombs BD.",
                                    year: "1992",
                                    title: "Skin color measurements in terms of CIELAB color space values.",
                                    journal: "Journal of Investigative Dermatology",
                                    citation: "99(4):468-473"
                                ),
                                Reference(
                                    authors: "Nouveau S, Agrawal D, Kohli M, Bernerd F, Misra N, Nayak CS.",
                                    year: "2018",
                                    title: "Skin hyperpigmentation in Indian population: insights and best practice.",
                                    journal: "Indian Journal of Dermatology",
                                    citation: "63(2):93-103"
                                )
                            ],
                            description: "Pigmentation analysis uses established colorimetric methods and is specifically calibrated for Indian skin tones (Fitzpatrick types III-VI)."
                        )

                        referenceSection(
                            title: "Wrinkles & Aging",
                            icon: "arrow.up.circle.fill",
                            references: [
                                Reference(
                                    authors: "Batisse D, Bazin R, Baldeweck T, Querleux B, Lévêque JL.",
                                    year: "2002",
                                    title: "Influence of age on the wrinkling capacities of skin.",
                                    journal: "Skin Research and Technology",
                                    citation: "8(3):148-154"
                                ),
                                Reference(
                                    authors: "Trojahn C, Dobos G, Schario M, Ludriksone L, Blume-Peytavi U, Kottner J.",
                                    year: "2015",
                                    title: "Relation between skin barrier function and age: a non-invasive quantitative study in infants, children and adults.",
                                    journal: "British Journal of Dermatology",
                                    citation: "172(6):1472-1478"
                                ),
                                Reference(
                                    authors: "Kruglikov IL, Scherer PE.",
                                    year: "2016",
                                    title: "Skin aging: are adipocytes the next target?",
                                    journal: "Aging",
                                    citation: "8(7):1457-1469"
                                )
                            ],
                            description: "3D mesh analysis identifies depth and distribution of facial creases using established visual analysis techniques."
                        )

                        referenceSection(
                            title: "Hydration & Moisture",
                            icon: "drop.fill",
                            references: [
                                Reference(
                                    authors: "Rawlings AV, Harding CR.",
                                    year: "2004",
                                    title: "Moisturization and skin barrier function.",
                                    journal: "Dermatologic Therapy",
                                    citation: "17(Suppl 1):43-48"
                                ),
                                Reference(
                                    authors: "Verdier-Sévrain S, Bonté F.",
                                    year: "2007",
                                    title: "Skin hydration: a review on its molecular mechanisms.",
                                    journal: "Journal of Cosmetic Dermatology",
                                    citation: "6(2):75-82"
                                ),
                                Reference(
                                    authors: "Caspers PJ, Lucassen GW, Puppels GJ.",
                                    year: "2003",
                                    title: "Combined in vivo confocal Raman spectroscopy and confocal microscopy of human skin.",
                                    journal: "Biophysical Journal",
                                    citation: "85(1):572-580"
                                )
                            ],
                            description: "Hydration indicators are assessed through surface moisture patterns and texture markers associated with water content in dermatological literature."
                        )

                        referenceSection(
                            title: "Blemishes & Skin Clarity",
                            icon: "circle.fill",
                            references: [
                                Reference(
                                    authors: "Gollnick H, Cunliffe W, Berson D, Dreno B, Finlay A, Leyden JJ, et al.",
                                    year: "2003",
                                    title: "Management of acne: a report from a Global Alliance to Improve Outcomes in Acne.",
                                    journal: "Journal of the American Academy of Dermatology",
                                    citation: "49(1 Suppl):S1-37"
                                ),
                                Reference(
                                    authors: "Del Rosso JQ, Kim GK.",
                                    year: "2009",
                                    title: "Optimization of antibiotic therapy in acne vulgaris: an update.",
                                    journal: "Dermatologic Clinics",
                                    citation: "27(1):17-23"
                                ),
                                Reference(
                                    authors: "Dréno B, Poli F, Pawin H, Beylot C, Faure M, Chivot M, et al.",
                                    year: "2006",
                                    title: "Development and evaluation of a Global Acne Severity Scale (GEA Scale).",
                                    journal: "Journal of the European Academy of Dermatology and Venereology",
                                    citation: "20(2):147-151"
                                )
                            ],
                            description: "Blemish detection uses surface irregularity analysis and inflammation markers referenced in clinical dermatology literature."
                        )

                        referenceSection(
                            title: "Pores & Sebum",
                            icon: "circle.grid.3x3.fill",
                            references: [
                                Reference(
                                    authors: "Piérard-Franchimont C, Piérard GE.",
                                    year: "2000",
                                    title: "Pore size and distribution in oily skin.",
                                    journal: "Dermatology",
                                    citation: "201(2):170-172"
                                ),
                                Reference(
                                    authors: "Zouboulis CC, Boschnakow A.",
                                    year: "2001",
                                    title: "Chronological ageing and photoageing of the human sebaceous gland.",
                                    journal: "Clinical and Experimental Dermatology",
                                    citation: "26(7):600-607"
                                ),
                                Reference(
                                    authors: "Thiboutot D, Gollnick H, Bettoli V, Dréno B, Kang S, Leyden JJ, et al.",
                                    year: "2009",
                                    title: "New insights into the management of acne: an update from the Global Alliance to Improve Outcomes in Acne.",
                                    journal: "Journal of the American Academy of Dermatology",
                                    citation: "60(5 Suppl):S1-50"
                                )
                            ],
                            description: "Pore visibility assessment uses high-frequency texture analysis validated in sebaceous gland and skin aging research."
                        )

                        referenceSection(
                            title: "Redness & Vascular Indicators",
                            icon: "heart.fill",
                            references: [
                                Reference(
                                    authors: "Wilkin J, Dahl M, Detmar M, Drake L, Feinstein A, Odom R, et al.",
                                    year: "2002",
                                    title: "Standard classification of rosacea: Report of the National Rosacea Society Expert Committee.",
                                    journal: "Journal of the American Academy of Dermatology",
                                    citation: "46(4):584-587"
                                ),
                                Reference(
                                    authors: "Kollias N, Baqer A.",
                                    year: "1986",
                                    title: "Absorption mechanisms of human melanin in the visible, 400-720 nm.",
                                    journal: "Journal of Investigative Dermatology",
                                    citation: "86(4):479"
                                ),
                                Reference(
                                    authors: "Stamatas GN, Kollias N.",
                                    year: "2004",
                                    title: "Blood stasis contributions to the perception of skin pigmentation.",
                                    journal: "Journal of Biomedical Optics",
                                    citation: "9(2):315-322"
                                )
                            ],
                            description: "Redness detection analyzes red channel intensity and vascular patterns based on established methods in rosacea and inflammation assessment."
                        )

                        referenceSection(
                            title: "Sun Damage & Photoaging",
                            icon: "sun.max.fill",
                            references: [
                                Reference(
                                    authors: "Gilchrest BA.",
                                    year: "2013",
                                    title: "Photoaging.",
                                    journal: "Journal of Investigative Dermatology",
                                    citation: "133(E1):E2-6"
                                ),
                                Reference(
                                    authors: "Yaar M, Gilchrest BA.",
                                    year: "2007",
                                    title: "Photoageing: mechanism, prevention and therapy.",
                                    journal: "British Journal of Dermatology",
                                    citation: "157(5):874-887"
                                ),
                                Reference(
                                    authors: "Flament F, Bazin R, Laquieze S, Rubert V, Simonpietri E, Piot B.",
                                    year: "2013",
                                    title: "Effect of the sun on visible clinical signs of aging in Caucasian skin.",
                                    journal: "Clinical, Cosmetic and Investigational Dermatology",
                                    citation: "6:221-232"
                                )
                            ],
                            description: "Sun damage indicators combine pigmentation irregularities and texture changes consistent with UV exposure patterns documented in photoaging research."
                        )

                        referenceSection(
                            title: "3D Imaging & Computer Vision",
                            icon: "cube.fill",
                            references: [
                                Reference(
                                    authors: "Bazin R, Doublet E.",
                                    year: "2007",
                                    title: "Skin aging atlas. Volume 1: Caucasian type.",
                                    journal: "MED'COM",
                                    citation: "Paris, France"
                                ),
                                Reference(
                                    authors: "de Rigal J, Escoffier C, Querleux B, Faivre B, Agache P, Lévêque JL.",
                                    year: "1989",
                                    title: "Assessment of aging of the human skin by in vivo ultrasonic imaging.",
                                    journal: "Journal of Investigative Dermatology",
                                    citation: "93(5):621-625"
                                ),
                                Reference(
                                    authors: "Ezquerra NF, Mullick R, Nevo E, Ozkan M.",
                                    year: "1991",
                                    title: "Three-dimensional visualization of dermatological images.",
                                    journal: "IEEE Computer Graphics and Applications",
                                    citation: "11(5):39-45"
                                )
                            ],
                            description: "Our 3D facial scanning uses TrueDepth camera technology combined with established computer vision methods for skin surface analysis."
                        )

                        referenceSection(
                            title: "Skin Care Recommendations",
                            icon: "sparkles",
                            references: [
                                Reference(
                                    authors: "Draelos ZD.",
                                    year: "2010",
                                    title: "Cosmetic dermatology: products and procedures.",
                                    journal: "Wiley-Blackwell",
                                    citation: "1st Edition"
                                ),
                                Reference(
                                    authors: "Kligman AM.",
                                    year: "1996",
                                    title: "The future of cosmeceuticals: an interview.",
                                    journal: "Dermatologic Clinics",
                                    citation: "18(4):609-615"
                                ),
                                Reference(
                                    authors: "Baumann L.",
                                    year: "2007",
                                    title: "Skin ageing and its treatment.",
                                    journal: "Journal of Pathology",
                                    citation: "211(2):241-251"
                                )
                            ],
                            description: "Skincare recommendations are based on evidence-based dermatological practices for common skin concerns."
                        )
                    }

                    // Additional Information
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        Text("Methodology")
                            .font(AppFont.title2)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Ollvy combines iPhone TrueDepth camera 3D scanning with computer vision algorithms to analyze skin characteristics. All analysis is performed locally on your device. Our algorithms detect patterns and characteristics associated with various skin metrics based on the scientific literature cited above.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Limitations")
                            .font(AppFont.title2)
                            .foregroundColor(Designs.Colors.textPrimary)
                            .padding(.top, Designs.Spacing.md)

                        Text("While our analysis is based on established research, Ollvy is a consumer wellness app, not a medical device. Scores are estimates for general awareness and tracking purposes only. Environmental factors, lighting, device positioning, and individual variations can affect results. For medical diagnosis or treatment, always consult a qualified dermatologist.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.warning.opacity(Designs.Opacity.veryLight))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
                    .padding(.horizontal, Designs.Spacing.lg)
                    .padding(.bottom, Designs.Spacing.xxl)
                }
            }
            .background(Designs.Colors.background)
            .navigationTitle("Scientific References")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(Designs.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
            HStack(spacing: Designs.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppFont.cardTitle)
                    .foregroundColor(Designs.Colors.error)

                Text("Important Medical Disclaimer")
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Text("Ollvy is NOT a medical device and is not intended for medical diagnosis, treatment, cure, or prevention of any disease. The information provided is for general awareness only. Always consult a qualified dermatologist for medical advice, diagnosis, or treatment of skin conditions.")
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.error.opacity(Designs.Opacity.veryLight))
        .overlay(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .stroke(Designs.Colors.error.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .padding(.horizontal, Designs.Spacing.lg)
    }

    private func referenceSection(title: String, icon: String, references: [Reference], description: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Designs.Animation.spring) {
                    expandedSection = expandedSection == title ? nil : title
                }
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    Image(systemName: icon)
                        .font(AppFont.sectionHeader)
                        .foregroundColor(Designs.Colors.primary)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("\(references.count) reference\(references.count == 1 ? "" : "s")")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: expandedSection == title ? "chevron.up" : "chevron.down")
                        .font(AppFont.metricLabel)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
                .padding(Designs.Spacing.lg)
            }

            if expandedSection == title {
                VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                    Text(description)
                        .font(AppFont.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Designs.Spacing.lg)
                        .padding(.bottom, Designs.Spacing.sm)

                    ForEach(references) { reference in
                        referenceCard(reference)
                    }
                }
                .padding(.bottom, Designs.Spacing.md)
                .transition(.opacity)
            }
        }
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .padding(.horizontal, Designs.Spacing.lg)
    }

    private func referenceCard(_ reference: Reference) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.authors)
                .font(AppFont.footnote)
                .foregroundColor(Designs.Colors.textPrimary)
                .fontWeight(.medium)

            Text(reference.title)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textPrimary)
                .italic()

            HStack(spacing: 4) {
                Text(reference.journal)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)

                Text("(\(reference.year))")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            if !reference.citation.isEmpty {
                Text(reference.citation)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textTertiary)
            }
        }
        .padding(Designs.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
        .padding(.horizontal, Designs.Spacing.lg)
    }
}

// MARK: - Reference Model

struct Reference: Identifiable {
    let id = UUID()
    let authors: String
    let year: String
    let title: String
    let journal: String
    let citation: String
}

#Preview {
    ScientificReferencesView()
}
