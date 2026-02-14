he following plan:                                                                                                                 
                                                                                                                                                
  # App Store Rejection Resolution Plan                                                                                                         
                                                                                                                                                
  **Issue**: Apple rejected Ollvy v1.0 for Guidelines 1.4.1 (Health Claims) and 2.1 (Face Data/Business Model)                                  
  **Strategy**: Reframe as cosmetic analysis + add inline citations + provide App Store Connect responses                                       
                                                                                                                                                
  ---                                                                                                                                           
                                                                                                                                                
  ## Part 1: Terminology Reframing (Remove Health Claims)                                                                                       
                                                                                                                                                
  ### 1.1 Core Property Renames in EmotionalMetrics.swift                                                                                       
                                                                                                                                                
  | Current | New | Line |                                                                                                                      
  |---------|-----|------|                                                                                                                      
  | `skinHealthScore` | `skinAppearanceScore` | 27 |                                                                                            
  | `freshness` | `dewiness` | 41 |                                                                                                             
  | `acneScore` | `blemishClarityScore` | 44 |                                                                                                  
  | `rednessScore` | `colorEvennessScore` | 46 |                                                                                                
  | `lipHealthScore` | `lipAppearanceScore` | 59 |                                                                                              
                                                                                                                                                
  **File**: `/Ollvy/Features/FaceScan3D/Models/EmotionalMetrics.swift`                                                                          
                                                                                                                                                
  ### 1.2 AppStrings.swift Updates                                                                                                              
                                                                                                                                                
  **File**: `/Ollvy/Shared/UI/AppStrings.swift`                                                                                                 
                                                                                                                                                
  - Line 88: `skinHealth` → `skinAppearance`                                                                                                    
  - Line 59: `skinAnalysis` → keep (acceptable)                                                                                                 
  - Add new string: `cosmeticDisclaimer`                                                                                                        
                                                                                                                                                
  ### 1.3 Files to Update (find-and-replace after core changes)                                                                                 
                                                                                                                                                
  | File | Changes |                                                                                                                            
  |------|---------|                                                                                                                            
  | `Face3DMetrics.swift` | `acneAnalysis` → `blemishAnalysis`, `rednessAnalysis` → `colorEvennessAnalysis` |                                   
  | `AcneAnalyzer.swift` | Rename file to `BlemishAnalyzer.swift`, update struct names |                                                        
  | `RednessAnalyzer.swift` | Update output descriptions (keep technical implementation) |                                                      
  | `HydrationEstimator.swift` | Rename to `MoistureAppearanceEstimator.swift` |                                                                
  | `MetricExplanations.swift` | Replace "skin health" with "skin appearance" throughout |                                                      
  | `CelebratoryResultsView.swift` | Update displayed labels |                                                                                  
  | `ResultsDetailView.swift` | Update metric labels |                                                                                          
  | `InsightsTabView.swift` | Update section headers |                                                                                          
  | `HomeView.swift` | Update any health terminology |                                                                                          
                                                                                                                                                
  ### 1.4 Add Cosmetic Disclaimer Component                                                                                                     
                                                                                                                                                
  Create `/Ollvy/Shared/UI/CosmeticDisclaimer.swift`:                                                                                           
                                                                                                                                                
  ```swift                                                                                                                                      
  public struct CosmeticDisclaimer: View {                                                                                                      
  public var body: some View {                                                                                                                  
  VStack(alignment: .leading, spacing: 8) {                                                                                                     
  Label("Visual Analysis Only", systemImage: "info.circle.fill")                                                                                
  .font(.subheadline.bold())                                                                                                                    
  Text("This analysis evaluates visible cosmetic characteristics. It is NOT a medical device and does not diagnose any health                   
  condition.")                                                                                                                                  
  .font(.caption)                                                                                                                               
  .foregroundColor(.secondary)                                                                                                                  
  }                                                                                                                                             
  .padding()                                                                                                                                    
  .background(Color.orange.opacity(0.1))                                                                                                        
  .cornerRadius(12)                                                                                                                             
  }                                                                                                                                             
  }                                                                                                                                             
  ```                                                                                                                                           
                                                                                                                                                
  **Add to these views:**                                                                                                                       
  - `CelebratoryResultsView.swift` (before score display)                                                                                       
  - `ResultsDetailView.swift` (in header)                                                                                                       
  - `InsightsTabView.swift` (at top)                                                                                                            
                                                                                                                                                
  ---                                                                                                                                           
                                                                                                                                                
  ## Part 2: Inline Citations System                                                                                                            
                                                                                                                                                
  ### 2.1 Create CitationLink Component                                                                                                         
                                                                                                                                                
  Create `/Ollvy/Shared/UI/CitationLink.swift`:                                                                                                 
                                                                                                                                                
  ```swift                                                                                                                                      
  public enum CitationKey: String, CaseIterable {                                                                                               
  case texture = "Setaro2001"                                                                                                                   
  case pigmentation = "Weatherall1992"                                                                                                          
  case wrinkles = "Batisse2002"                                                                                                                 
  case hydration = "Rawlings2004"                                                                                                               
  case acne = "Gollnick2003"                                                                                                                    
  case pores = "Pierard2000"                                                                                                                    
  case redness = "Wilkin2002"                                                                                                                   
  case sunDamage = "Gilchrest2013"                                                                                                              
                                                                                                                                                
  var shortCode: String {                                                                                                                       
  switch self {                                                                                                                                 
  case .texture: return "1"                                                                                                                     
  case .pigmentation: return "2"                                                                                                                
  // ... etc                                                                                                                                    
  }                                                                                                                                             
  }                                                                                                                                             
  }                                                                                                                                             
                                                                                                                                                
  public struct CitationLink: View {                                                                                                            
  let key: CitationKey                                                                                                                          
  @State private var showingDetail = false                                                                                                      
                                                                                                                                                
  public var body: some View {                                                                                                                  
  Button { showingDetail = true } label: {                                                                                                      
  Text("[\(key.shortCode)]")                                                                                                                    
  .font(.caption)                                                                                                                               
  .foregroundColor(.blue)                                                                                                                       
  }                                                                                                                                             
  .sheet(isPresented: $showingDetail) {                                                                                                         
  CitationDetailView(key: key)                                                                                                                  
  }                                                                                                                                             
  }                                                                                                                                             
  }                                                                                                                                             
  ```                                                                                                                                           
                                                                                                                                                
  ### 2.2 Update Recommendation Engine                                                                                                          
                                                                                                                                                
  **File**: `/Ollvy/Features/Recommendations/PersonalizedRecommendationEngine.swift`                                                            
                                                                                                                                                
  Add `citationKeys: [CitationKey]` property to `Recommendation` struct and populate in each `createXxxRecommendation` method.                  
                                                                                                                                                
  ### 2.3 Citation Mapping                                                                                                                      
                                                                                                                                                
  | Recommendation Topic | Citation |                                                                                                           
  |---------------------|----------|                                                                                                            
  | Texture/Smoothness | Setaro 2001 |                                                                                                          
  | Pigmentation/Tone | Weatherall 1992 |                                                                                                       
  | Wrinkles/Lines | Batisse 2002 |                                                                                                             
  | Moisture Appearance | Rawlings 2004 |                                                                                                       
  | Blemish Care | Gollnick 2003 |                                                                                                              
  | Pore Visibility | Pierard 2000 |                                                                                                            
  | Color Evenness | Wilkin 2002 |                                                                                                              
  | Sun Protection | Gilchrest 2013 |                                                                                                           
                                                                                                                                                
  ---                                                                                                                                           
                                                                                                                                                
  ## Part 3: App Store Connect Responses                                                                                                        
                                                                                                                                                
  ### 3.1 Guideline 1.4.1 - Health Claims Response                                                                                              
                                                                                                                                                
  ```                                                                                                                                           
  Ollvy is a COSMETIC VISUAL ANALYSIS app, NOT a medical/health app.                                                                            
                                                                                                                                                
  WHAT OLLVY DOES:                                                                                                                              
  - Captures 3D face model using TrueDepth camera                                                                                               
  - Analyzes VISIBLE cosmetic characteristics (texture, color evenness)                                                                         
  - Provides cosmetic suggestions (e.g., "consider SPF")                                                                                        
  - Visual observation only, similar to looking in a mirror                                                                                     
                                                                                                                                                
  WHAT OLLVY DOES NOT DO:                                                                                                                       
  - Does NOT diagnose, measure, or treat any health condition                                                                                   
  - Does NOT provide medical advice                                                                                                             
  - Does NOT claim to measure "skin health" - we use "skin appearance"                                                                          
  - Does NOT measure biometrics for health purposes                                                                                             
                                                                                                                                                
  DISCLAIMERS IN APP:                                                                                                                           
  "Ollvy is NOT a medical device. It is for general cosmetic                                                                                    
  awareness only. Consult a qualified dermatologist for medical advice."                                                                        
                                                                                                                                                
  UPDATES MADE:                                                                                                                                 
  1. Replaced "Skin Health" → "Skin Appearance" throughout                                                                                      
  2. Replaced "Acne Detection" → "Blemish Visibility Analysis"                                                                                  
  3. Replaced "Hydration" → "Surface Moisture Appearance"                                                                                       
  4. Added inline citations to all recommendations                                                                                              
  5. Added prominent cosmetic-only disclaimers                                                                                                  
  ```                                                                                                                                           
                                                                                                                                                
  ### 3.2 Guideline 2.1 - Face Data Response                                                                                                    
                                                                                                                                                
  ```                                                                                                                                           
  WHAT FACE DATA IS COLLECTED:                                                                                                                  
  - 3D facial mesh geometry (vertices, triangles)                                                                                               
  - Facial texture image (color from face surface)                                                                                              
  - NOT used for biometric authentication                                                                                                       
                                                                                                                                                
  HOW FACE DATA IS USED:                                                                                                                        
  1. Texture analysis - surface smoothness patterns                                                                                             
  2. Color analysis - tone evenness evaluation                                                                                                  
  3. Progress tracking - compare to previous scans                                                                                              
                                                                                                                                                
  THIRD-PARTY SHARING: NONE                                                                                                                     
  - All processing occurs 100% on-device                                                                                                        
  - Face data NEVER transmitted to any server                                                                                                   
  - No third-party services receive face data                                                                                                   
                                                                                                                                                
  DATA STORAGE:                                                                                                                                 
  - Stored locally in iOS app sandbox (Core Data)                                                                                               
  - iOS default encryption applies                                                                                                              
  - User can delete all data via Settings > Delete All Data                                                                                     
                                                                                                                                                
  DATA RETENTION:                                                                                                                               
  - Stored until user deletion                                                                                                                  
  - Deleted when app is uninstalled                                                                                                             
  - No automatic expiration                                                                                                                     
                                                                                                                                                
  PRIVACY POLICY QUOTES (Section: "Facial Scan Data"):                                                                                          
  "All your facial scan data is processed and stored locally on                                                                                 
  your device. We never upload your face images to any server."                                                                                 
                                                                                                                                                
  "We do not use facial data for biometric authentication.                                                                                      
  TrueDepth data is used solely for skin visual analysis."                                                                                      
  ```                                                                                                                                           
                                                                                                                                                
  ### 3.3 Guideline 2.1 - TrueDepth API Response                                                                                                
                                                                                                                                                
  ```                                                                                                                                           
  TRUEDEPTH API USAGE:                                                                                                                          
  - ARFaceTrackingConfiguration for face mesh capture                                                                                           
  - ARFaceGeometry for 3D vertex data                                                                                                           
  - Light estimation for consistent analysis                                                                                                    
  - NOT used for Face ID or authentication                                                                                                      
                                                                                                                                                
  DATA COLLECTED:                                                                                                                               
  - Face mesh (vertices, normals, UVs)                                                                                                          
  - Facial texture from ARFrame                                                                                                                 
  - Light estimation values                                                                                                                     
                                                                                                                                                
  PROCESSING: 100% on-device using Metal/Core ML                                                                                                
  STORAGE: Local only (Core Data in app sandbox)                                                                                                
  SHARING: None - never transmitted                                                                                                             
                                                                                                                                                
  PRIVACY POLICY LOCATION:                                                                                                                      
  Settings > Privacy Policy, Section "TrueDepth Camera Usage"                                                                                   
                                                                                                                                                
  QUOTE: "Ollvy uses Apple's TrueDepth camera exclusively for                                                                                   
  creating a 3D model of your face for cosmetic skin analysis.                                                                                  
  This data never leaves your device."                                                                                                          
  ```                                                                                                                                           
                                                                                                                                                
  ### 3.4 Guideline 2.1 - Business Model Response                                                                                               
                                                                                                                                                
  ```                                                                                                                                           
  BUSINESS MODEL: Free app with no monetization                                                                                                 
                                                                                                                                                
  1. WHO ARE USERS: General consumers interested in tracking                                                                                    
  skin appearance over time                                                                                                                     
                                                                                                                                                
  2. WHERE PURCHASED: App is FREE on App Store - no purchases                                                                                   
                                                                                                                                                
  3. PREVIOUSLY PURCHASED CONTENT: None - no external purchases                                                                                 
  can be accessed in app                                                                                                                        
                                                                                                                                                
  4. PAID FEATURES WITHOUT IAP: None - all features are free                                                                                    
                                                                                                                                                
  5. ACCOUNT CREATION: No account required. Optional local-only                                                                                 
  profile (stored on device). No fees.                                                                                                          
                                                                                                                                                
  REVENUE: Currently no revenue model. Future options may include                                                                               
  premium features via Apple IAP (not yet implemented).                                                                                         
  ```                                                                                                                                           
                                                                                                                                                
  ---                                                                                                                                           
                                                                                                                                                
  ## Part 4: Implementation Order                                                                                                               
                                                                                                                                                
  ### Phase 1: Core Model Updates                                                                                                               
  1. Update `EmotionalMetrics.swift` property names                                                                                             
  2. Add `CodingKeys` for backward compatibility with stored data                                                                               
  3. Update `AppStrings.swift`                                                                                                                  
                                                                                                                                                
  ### Phase 2: Analyzer Renames                                                                                                                 
  4. Rename `AcneAnalyzer.swift` → `BlemishAnalyzer.swift`                                                                                      
  5. Rename `HydrationEstimator.swift` → `MoistureAppearanceEstimator.swift`                                                                    
  6. Update `Face3DMetrics.swift` references                                                                                                    
  7. Update `MetricsOrchestrator.swift` imports                                                                                                 
                                                                                                                                                
  ### Phase 3: UI Updates                                                                                                                       
  8. Create `CosmeticDisclaimer.swift`                                                                                                          
  9. Create `CitationLink.swift`                                                                                                                
  10. Update results views with disclaimer                                                                                                      
  11. Update metric labels in all views                                                                                                         
                                                                                                                                                
  ### Phase 4: Citation Integration                                                                                                             
  12. Add citations to `PersonalizedRecommendationEngine.swift`                                                                                 
  13. Add inline citation links in recommendation views                                                                                         
                                                                                                                                                
  ### Phase 5: Testing                                                                                                                          
  14. Build and fix compilation errors                                                                                                          
  15. Test backward compatibility (old scans should still load)                                                                                 
  16. Verify all health terminology removed                                                                                                     
  17. Test citation links work                                                                                                                  
                                                                                                                                                
  ---                                                                                                                                           
                                                                                                                                                
  ## Verification Checklist                                                                                                                     
                                                                                                                                                
  - [ ] No instances of "skin health" remain (search codebase)                                                                                  
  - [ ] No instances of "acne" in user-facing text (can remain in technical code)                                                               
  - [ ] No instances of "hydration" in user-facing text                                                                                         
  - [ ] Cosmetic disclaimer visible on results screens                                                                                          
  - [ ] Citations appear inline with recommendations                                                                                            
  - [ ] App builds without errors                                                                                                               
  - [ ] Old scan data still loads (backward compatibility)                                                                                      
  - [ ] Privacy policy text matches quoted responses                                                                                            
                                                            