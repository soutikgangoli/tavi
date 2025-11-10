# Tavi App Redesign Specification

## Complete App Sitemap Structure

```
┌─────────────────────────────────────────────────┐
│           BOTTOM TAB NAVIGATION (5 Tabs)        │
│  [Home] [History] [+ Scan] [Insights] [Profile] │
└─────────────────────────────────────────────────┘

Tab 1: 🏠 HOME
├─ Home Screen (Has Scans)
├─ Home Screen (Empty State - First Time)
└─ Metric Detail Views (drill-down from rings)
    ├─ Overall Score Detail
    ├─ Glow Score Detail
    └─ Hydration Score Detail

Tab 2: 📊 HISTORY
├─ History List (All Scans)
└─ Scan Detail View (from history)
    └─ Comparison View (compare 2 scans)

Tab 3: ➕ SCAN (Center Tab)
├─ Scan Preparation Screen
├─ Calibration & Guidance
├─ Capture Flow
└─ Processing Screen
    └─ Celebratory Results → Returns to Home

Tab 4: 💡 INSIGHTS
├─ Insights Dashboard
├─ Recommendations
├─ Progress Trends
└─ Educational Content

Tab 5: 👤 PROFILE
├─ User Profile
├─ Achievements & Badges
├─ Challenge Progress
└─ Settings
```

---

## PAGE 1: HOME SCREEN (Has Scans State)

### Visual Layout

```
┌─────────────────────────────────────────────┐
│ 9:41                            [●●●] [≣]   │ System status
│                                              │
│ Today, 14 September ▼                  [S]  │ Header
│                                              │
│ ┌──────────────────────┐ ┌───────────────┐ │
│ │ 🔥 Active            │ │ Last Scan     │ │ Status widgets
│ │ 12 days • 60% done ▼ │ │ 2 days ago    │ │
│ └──────────────────────┘ └───────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │   ┌────┐      ┌────┐      ┌────┐       │ │
│ │   │ 85 │      │ 72 │      │ 68 │       │ │ 3 Hero Rings
│ │   │ %  │      │ %  │      │ %  │       │ │
│ │   └────┘      └────┘      └────┘       │ │
│ │  Overall     Glow    Hydration          │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Great Progress!                      ↗  │ │
│ │                                          │ │
│ │ Your latest scan from 2 days ago shows  │ │ Latest Scan
│ │ improvement in glow (+8%) and hydration │ │ Summary Card
│ │ (+5%). Smoothness increased by 3%.      │ │
│ │                                          │ │
│ │ Overall Score: 85 (+3 from last scan)   │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Your Progress                                │
│ ┌─────────────────────────────────────────┐ │
│ │       ●                                  │ │
│ │    ●     ●                               │ │ Progress Chart
│ │ ●           ●                            │ │
│ │────────────────────────────────────────  │ │
│ │ Week 1  Week 2  Week 3  Week 4          │ │
│ │ [1M] [3M] [6M] [1Y]                     │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Recent scans                                 │
│ ┌─────────────────────────────────────────┐ │
│ │ Sep │ 85 │ 2 days ago      +3%  [→]    │ │
│ │ 12  │    │                              │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │ Recent Scans
│ │ Sep │ 82 │ 5 days ago      +2%  [→]    │ │ (5 max)
│ │ 7   │    │                              │ │
│ └─────────────────────────────────────────┘ │
│ ... (3 more)                                 │
│                                              │
│         [View All Scans (12) →]             │
│                                              │
│ [Bottom spacing for tab bar]                 │
└─────────────────────────────────────────────┘
│  [🏠]  [📊]  [➕]  [💡]  [👤]              │ Bottom Tab Bar
│  Home History Scan Insights Profile         │
└─────────────────────────────────────────────┘
```

### Data Sources & Logic

#### 1. Header Section
**Component:** `dateHeaderSection`

**Data:**
- **Date:** `Date()` → formatted as "Today, DD MMMM" using `DateFormatter`
- **Profile Icon:** `UserProfileManager.shared.loadProfile().name` (first letter) or fallback icon
  - Source: `UserDefaults` key `"userProfile"`

**Logic:**
```swift
let formatter = DateFormatter()
formatter.dateFormat = "d MMMM"
let dateString = formatter.string(from: Date())
// Result: "14 September"
```

**User Interaction:**
- Date dropdown (▼): Opens date picker to view historical data
- Profile icon tap: Navigates to Profile tab

---

#### 2. Status Widgets Row

**Left Widget: Active Challenge Status**

**Data Source:** `GamificationManager.shared.getCurrentChallenge()`
- Returns: `GlowChallenge?` from UserDefaults key `"currentGlowChallenge"`

**Display Logic:**
```swift
if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
    let daysCompleted = challenge.daysCompleted
    let totalDays = challenge.goalDays // 30
    let progress = (daysCompleted / totalDays) * 100

    Text("\(daysCompleted) days • \(Int(progress))% done")
} else {
    Text("Start your 30-day challenge")
}
```

**Data Fields:**
- `challenge.daysCompleted`: Int (from `challenge.checkIns.count`)
- `challenge.goalDays`: Int (30)
- `challenge.isActive`: Bool

**Right Widget: Last Scan Info**

**Data Source:** `sessions.first` (Core Data `@FetchRequest`)
- Query: `SessionResult` sorted by `date` descending
- Returns: Most recent `SessionResult`

**Display Logic:**
```swift
if let lastScan = sessions.first {
    let relativeDate = formatRelativeDate(lastScan.date)
    // "2 days ago", "Today", "Yesterday", etc.
}
```

**Calculation:**
```swift
func formatRelativeDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day], from: date, to: now)

    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else if let days = components.day, days < 7 {
        return "\(days) days ago"
    } else {
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
```

---

#### 3. Three Hero Rings

**Data Source:** `sessions.first` (latest SessionResult)

**Ring 1: Overall Score**
- **Value:** `sessions.first?.overallScore ?? 0`
- **Type:** `Double` (0-100)
- **Source:** Core Data `SessionResult.overallScore`
- **Calculated:** During scan processing in `ProcessingPipeline`

**Color Logic:**
```swift
func scoreColor(_ score: Double) -> Color {
    switch score {
    case 90...100: return .green
    case 80..<90: return Color(red: 101/255, green: 188/255, blue: 126/255)
    case 50..<80: return .yellow
    case 30..<50: return .orange
    default: return .red
    }
}
```

**Ring 2: Glow Score**
- **Value:** `sessions.first?.skinMetrics?.glowScore ?? 0`
- **Type:** `Double` (0-100)
- **Source:** Core Data `SessionResult` → `SkinMetrics.glowScore`
- **Calculated:** By `GlowAnalyzer` during scan

**Data Path:**
```
SessionResult → skinMetrics (relationship) → SkinMetrics
SkinMetrics.glowScore: Double
```

**Ring 3: Hydration Score**
- **Value:** `sessions.first?.skinMetrics?.hydrationScore ?? 0`
- **Type:** `Double` (0-100)
- **Source:** Core Data `SkinMetrics.hydrationScore`
- **Calculated:** By `HydrationEstimator` during scan

**Tap Interaction:**
- Tapping ring → Navigate to Metric Detail View (modal)
- Pass `MetricType`: `.overall`, `.glow`, or `.hydration`

---

#### 4. Latest Scan Summary Card

**Data Source:** `sessions.first` + previous scan comparison

**Calculation Logic:**
```swift
guard let latestScan = sessions.first else { return nil }
let previousScan = sessions.dropFirst().first

// Calculate changes
var glowChange: Double = 0
var hydrationChange: Double = 0
var smoothnessChange: Double = 0

if let previous = previousScan {
    glowChange = latestScan.glowScore - previous.glowScore
    hydrationChange = latestScan.hydrationScore - previous.hydrationScore
    smoothnessChange = latestScan.smoothnessScore - previous.smoothnessScore
}
```

**Text Generation:**
```swift
func generateSummaryText(glowChange: Double, hydrationChange: Double, smoothnessChange: Double) -> String {
    var improvements: [String] = []

    if glowChange > 2 {
        improvements.append("glow (+\(Int(glowChange))%)")
    }
    if hydrationChange > 2 {
        improvements.append("hydration (+\(Int(hydrationChange))%)")
    }
    if smoothnessChange > 2 {
        improvements.append("smoothness (+\(Int(smoothnessChange))%)")
    }

    if improvements.isEmpty {
        return "Your skin metrics are stable. Keep up your routine!"
    } else {
        let joined = improvements.joined(separator: " and ")
        return "Your latest scan shows improvement in \(joined)."
    }
}
```

**Data Fields:**
- `latestScan.date`: Date
- `latestScan.overallScore`: Double
- `latestScan.glowScore`: Double
- `latestScan.hydrationScore`: Double
- `latestScan.smoothnessScore`: Double
- `previousScan.overallScore`: Double (for comparison)

**Special Case - First Scan:**
```swift
if sessions.count == 1 {
    return "This is your baseline scan. Complete another scan to track progress!"
}
```

---

#### 5. Progress Chart

**Component:** Existing `ProgressGraphView`

**Data Source:** `Array(sessions)`
- Minimum 2 scans required

**Display Logic:**
```swift
if sessions.count >= 2 {
    ProgressGraphView(sessions: Array(sessions))
}
```

**Time Range Filter:**
```swift
enum TimeRange {
    case oneMonth, threeMonths, sixMonths, oneYear
}

var filteredSessions: [SessionResult] {
    let cutoffDate: Date
    switch selectedRange {
    case .oneMonth:
        cutoffDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    case .threeMonths:
        cutoffDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    // ... etc
    }
    return sessions.filter { $0.date >= cutoffDate }
}
```

**Chart Data:**
- X-axis: `session.date` (formatted)
- Y-axis: `session.overallScore` (0-100)

---

#### 6. Recent Scans Section

**Data Source:** `Array(sessions.prefix(5))`

**For each scan:**
```swift
ForEach(Array(sessions.prefix(5)), id: \.id) { session in
    let dayMonth = formatDayMonth(session.date) // "Sep 12"
    let score = Int(session.overallScore) // 85
    let color = scoreColor(session.overallScore)
    let relativeDate = session.relativeDate // "2 days ago"
    let trend = calculateTrend(for: session) // +3, -2, etc.
}
```

**Trend Calculation:**
```swift
func calculateTrend(for session: SessionResult) -> Double? {
    guard let index = sessions.firstIndex(where: { $0.id == session.id }),
          index < sessions.count - 1 else {
        return nil
    }

    let previousSession = sessions[index + 1]
    let scoreDiff = session.overallScore - previousSession.overallScore
    return scoreDiff
}
```

**"View All" Button:**
```swift
if sessions.count > 5 {
    Button("View All Scans (\(sessions.count))") {
        // Switch to History tab
        selectedTab = .history
    }
}
```

---

### Conditional Rendering

**Show this state when:**
```swift
if sessions.count > 0 {
    // Show "Has Scans" state
} else {
    // Show empty state
}
```

**Core Data Structure:**
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
    animation: .default
)
private var sessions: FetchedResults<SessionResult>
```

**SessionResult Entity:**
- `id`: UUID
- `date`: Date
- `overallScore`: Double
- Relationship: `skinMetrics` → SkinMetrics

**SkinMetrics Entity:**
- `glowScore`: Double
- `hydrationScore`: Double
- `smoothnessScore`: Double
- `pigmentationScore`: Double
- `acneScore`: Double
- `sunDamageScore`: Double
- `rednessScore`: Double
- `roughnessScore`: Double

---

## PAGE 1: HOME SCREEN (Empty State - No Scans)

### Visual Layout

```
┌─────────────────────────────────────────────┐
│ 9:41                            [●●●] [≣]   │
│                                              │
│ Good morning, Alex                      [S] │ Greeting
│ Track your skin health journey              │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ ✨                                       │ │
│ │ Discover Your Skin Health               │ │ Benefits Card
│ │                                          │ │ (COMPACT)
│ │ [Track Progress] [Personalized]         │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ 🔥                                       │ │
│ │ 30-Day Glow Challenge                   │ │ Challenge
│ │                                          │ │ Invitation
│ │ ✓ Track daily progress                  │ │
│ │ ✓ Unlock achievements                   │ │
│ │ ✓ See glow improvements                 │ │
│ │                                          │ │
│ │ Complete your first scan to start       │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ 8 Skin Health Metrics                       │
│ ┌──────────┐ ┌──────────┐                  │
│ │ Smoothne │ │ Hydratio │  ... (6 more)   │ 8 Metrics Grid
│ │    ss    │ │    n     │                  │
│ └──────────┘ └──────────┘                  │
│                                              │
│ Advanced 3D Face Scanning                   │
│ ┌─────────────────────────────────────────┐ │
│ │ 📷 Advanced 3D Face Scanning            │ │ Technology Card
│ │ ✓ 5-pose capture                        │ │
│ │ ✓ Clinical-grade accuracy (83-92%)      │ │
│ │ ✓ Privacy-first • Data stays on device  │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ 💡 Pro tip                              │ │ Pro Tip
│ │ Scan in bright, natural light           │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ [Bottom spacing]                             │
└─────────────────────────────────────────────┘
│  [🏠]  [📊]  [➕]  [💡]  [👤]              │ Tab Bar
└─────────────────────────────────────────────┘
```

### Data Sources - Empty State

#### 1. Greeting Section
**Data:**
- `UserProfileManager.shared.loadProfile().name ?? "there"`
- Time-based greeting: `getTimeBasedGreeting()`

**Logic:**
```swift
let hour = Calendar.current.component(.hour, from: Date())
let greeting = switch hour {
    case 0..<12: "Good morning"
    case 12..<17: "Good afternoon"
    default: "Good evening"
}
```

#### 2. Compact Benefits Card
**Data:** Static text (educational)

#### 3. Challenge Invitation Card
**Data:** Static text (no active challenge yet)

**Condition:**
```swift
if sessions.count == 0 && GamificationManager.shared.getCurrentChallenge() == nil {
    challengeInvitationCard
}
```

#### 4-6. Static Educational Cards
- 8 Metrics Grid: Shows metric names and icons (no scores)
- Technology Card: Static features list
- Pro Tips: Static guidance text

---

## State Comparison Table

| Element | Empty State (0 scans) | First Scan (1 scan) | Has Data (2+ scans) |
|---------|----------------------|-------------------|-------------------|
| **Header** | Greeting | Date | Date |
| **Status Widgets** | ❌ Hidden | ✅ Shows (Start Challenge + Last Scan) | ✅ Shows (Active Challenge + Last Scan) |
| **Hero Rings** | ❌ Hidden | ✅ Shows baseline scores | ✅ Shows latest scores |
| **Latest Summary** | ❌ Hidden | ✅ "Baseline scan" text | ✅ Comparison insights |
| **Progress Chart** | ❌ Hidden | ❌ Hidden (need 2+) | ✅ Shows trend |
| **Recent Scans** | ❌ Hidden | ✅ Shows 1 scan | ✅ Shows up to 5 |
| **View All Button** | ❌ Hidden | ❌ Hidden (need 6+) | ✅ Shows if > 5 |
| **Benefits Card** | ✅ Shows | ❌ Hidden | ❌ Hidden |
| **Challenge Invite** | ✅ Shows | ❌ Hidden | ❌ Hidden |
| **8 Metrics Grid** | ✅ Shows | ❌ Hidden | ❌ Hidden |
| **Technology Card** | ✅ Shows | ❌ Hidden | ❌ Hidden |
| **Pro Tips** | ✅ Shows | ❌ Hidden | ❌ Hidden |

---

## PAGE 2: METRIC DETAIL VIEW

### Visual Layout

```
┌─────────────────────────────────────────────┐
│ [←]          Overall Score              [ⓘ] │
│         Today, 14 September ▼                │
│                                              │
│          ┌──────────────┐                    │
│          │              │                    │
│          │      85%     │  Large ring        │
│          │   Excellent  │                    │
│          │              │                    │
│          └──────────────┘                    │
│                                              │
│  Normal range                                │
│  ≡ 80 - 100%                                │
│                                              │
│ [Overall Score] [Breakdown] [History]       │ ← Tabs
│                                              │
│ ┌────────────────────────────────────────┐  │
│ │        Score History Chart             │  │
│ │                                        │  │
│ │  100┐              ●                  │  │
│ │   80┤           ●  │ ●                │  │
│ │   60┤        ●     │    ●             │  │
│ │   40┤     ●        │       ●          │  │
│ │   20┤  ●           │          ●       │  │
│ │    0└─────────────────────────────────    │  │
│ │     15 Aug  22 Aug  30 Aug  6 Sep    │  │
│ │                                        │  │
│ │         Avg. 82%                      │  │
│ └────────────────────────────────────────┘  │
│                                              │
│ [1M] [3M] [6M] [1Y] [📅]                    │
│                                              │
│ Score Breakdown                              │
│ ┌────────────────────────────────────────┐  │
│ │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░  85%          │  │
│ └────────────────────────────────────────┘  │
│ ● Excellent  85-100%                        │
│ ● Good       70-84%                         │
│ ● Fair       50-69%                         │
└─────────────────────────────────────────────┘
```

**Triggered by:** Tapping hero rings on Home

**Data Source:**
- Selected metric type (Overall, Glow, or Hydration)
- Historical data for that metric from all sessions

---

## PAGE 3: HISTORY (All Scans List)

### Visual Layout

```
┌─────────────────────────────────────────────┐
│            Scan History                      │
│                                              │
│ [All] [Last 30 Days] [Last 3 Months]        │ ← Filters
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Sep  ● 85  Today           ↗️ [Compare] │ │
│ │ 12        Great progress              → │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Sep  ● 82  2 days ago      ↗️ [Compare] │ │
│ │ 7         Good condition              → │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ... (all historical scans)                  │
│                                              │
│ [Pull to refresh]                           │
└─────────────────────────────────────────────┘
```

**Component:** Existing `ResultsHistoryView` (enhanced)

**Features:**
- Filter chips: All, Last 30 Days, Last 3 Months
- Pull-to-refresh
- Delete via swipe or context menu
- Compare button
- Empty state: "No scans yet. Tap + to start!"

---

## PAGE 4: SCAN DETAIL VIEW

### Visual Layout

```
┌─────────────────────────────────────────────┐
│ [←]          Scan Results              [ⓘ]  │
│         Today, 14 September ▼                │
│                                              │
│        [Scenic background image]             │
│          ┌──────────────┐                    │
│          │              │                    │
│          │     85%      │  Large ring        │
│          │  Excellent   │                    │
│          │              │                    │
│          └──────────────┘                    │
│                                              │
│ ┌──────────────────┐  ┌──────────────────┐  │
│ │ 💧 Hydration     │  │ ✨ Glow          │  │
│ │   72%            │  │   68%            │  │
│ └──────────────────┘  └──────────────────┘  │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Great Improvement Detected           ↗️ │ │
│ │                                          │ │
│ │ Your skin shows significant improvement │ │
│ │ in hydration (+8%) and glow (+5%).      │ │
│ │ Your consistent skincare routine is     │ │
│ │ paying off! Keep it up!                 │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ✨ View insights                          → │
│                                              │
│ Timeline                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ 🌙 Night Routine                      → │ │
│ │ 14/09/25 at 10:00 PM                    │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Metrics Breakdown                            │
│ ┌─────────────────────────────────────────┐ │
│ │ Smoothness      ▬▬▬▬▬▬▬▬▬░░  85%      │ │
│ │ Hydration       ▬▬▬▬▬▬▬░░░░  72%      │ │
│ │ Glow            ▬▬▬▬▬▬░░░░░  68%      │ │
│ │ Pigmentation    ▬▬▬▬▬▬▬▬░░░  78%      │ │
│ │ Acne            ▬▬▬▬▬▬▬▬▬▬░  92%      │ │
│ │ Sun Damage      ▬▬▬▬▬▬▬░░░░  70%      │ │
│ │ Redness         ▬▬▬▬▬▬▬▬░░░  80%      │ │
│ │ Roughness       ▬▬▬▬▬▬▬░░░░  75%      │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ [Compare with Previous Scan]                 │
│ [Share Results]                              │
│ [Delete Scan]                                │
└─────────────────────────────────────────────┘
```

**Triggered by:** Tapping a scan from History or Recent Scans

**Data Source:** Selected `SessionResult` from Core Data

---

## PAGE 5: SCAN FLOW (Center Tab)

### Flow Diagram

```
┌─────────────────────────────────────────────┐
│ 1. Scan Preparation Screen                  │
│    - Instructions                            │
│    - Lighting check                          │
│    - [3-2-1 Countdown]                      │
│    - [Skip] button                           │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 2. AR Face Tracking                          │
│    - Live camera view                        │
│    - Face mesh overlay                       │
│    - Real-time guidance badges               │
│    - Distance / Direction / Expression       │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 3. 5-Pose Capture Sequence                   │
│    - Look Straight → Turn Left → Turn Right  │
│    - Look Up → Look Down                     │
│    - Capture 3 frames per pose (or 5 if HQ)  │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 4. Processing Screen                         │
│    - Fancy loading animation                 │
│    - Progress messages                       │
│    - "Analyzing skin texture..."             │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 5. Celebratory Results                       │
│    - Score reveal animation                  │
│    - Confetti/celebration                    │
│    - [View Details] → Home tab               │
└─────────────────────────────────────────────┘
```

**Behavior:**
- Hide tab bar during scan flow
- Show tab bar on results screen
- After viewing results → Return to Home tab

---

## PAGE 6: INSIGHTS TAB

### Visual Layout

```
┌─────────────────────────────────────────────┐
│              Insights                        │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ 💡 For You                              │ │
│ │ Based on your latest scan...            │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Great Improvement Detected           ↗️ │ │
│ │                                          │ │
│ │ Your skin shows +8% hydration and       │ │
│ │ +5% glow improvement!                   │ │
│ │                                          │ │
│ │ [View Details →]                        │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ 🌟 Recommendation                     ↗️ │ │
│ │                                          │ │
│ │ Your hydration levels are excellent!    │ │
│ │ Continue using moisturizer twice daily. │ │
│ │                                          │ │
│ │ [Learn More →]                          │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ ⚠️ Area to Watch                      ↗️ │ │
│ │                                          │ │
│ │ Roughness decreased by 3%. Consider     │ │
│ │ adding exfoliation to your routine.     │ │
│ │                                          │ │
│ │ [View Tips →]                           │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Progress Trends                              │
│ ┌─────────────────────────────────────────┐ │
│ │ [Multi-metric chart showing all 8]      │ │
│ │ [1W] [1M] [3M] [6M] [1Y]                │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Educational Content                          │
│ ┌─────────────────────────────────────────┐ │
│ │ 📚 Understanding Hydration            → │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ 📚 What Affects Glow?                 → │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Sections:**
1. Personalized insight cards based on latest scan
2. AI-generated recommendations
3. Areas needing attention
4. Multi-metric comparison chart
5. Educational articles

---

## PAGE 7: PROFILE TAB

### Visual Layout

```
┌─────────────────────────────────────────────┐
│              Profile                         │
│                                              │
│        ┌──────────┐                          │
│        │   [S]    │  Profile photo           │
│        └──────────┘                          │
│                                              │
│          Alex Smith                          │
│      alex@email.com                          │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ 🔥 30-Day Glow Challenge              → │ │
│ │                                          │ │
│ │ Day 12 of 30    ▬▬▬▬▬░░░░░░  40%       │ │
│ │ Keep it up!                             │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Achievements                                 │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │
│ │ 🏆   │ │ ⭐   │ │ 💪   │ │ 🎯   │        │
│ │First │ │Week  │ │Month │ │Consi│        │
│ │Scan  │ │Streak│ │Streak│ │stent│        │
│ └──────┘ └──────┘ └──────┘ └──────┘        │
│                                              │
│ Stats                                        │
│ ┌─────────────────────────────────────────┐ │
│ │ Total Scans          12                 │ │
│ │ Current Streak       8 days             │ │
│ │ Best Score           92                 │ │
│ │ Average Score        85                 │ │
│ │ Improvement          +12% (30 days)     │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ Settings                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Account Settings                      → │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Scan Settings                         → │ │
│ │ High Quality Mode: ON                   │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Notifications                         → │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Privacy & Data                        → │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ About & Help                          → │ │
│ └─────────────────────────────────────────┘ │
│                                              │
│ [Sign Out]                                   │
└─────────────────────────────────────────────┘
```

**Sections:**
1. Profile header (photo, name, email)
2. Active challenge progress
3. Achievements grid (unlocked badges)
4. Statistics (scans, streak, scores)
5. Settings navigation links

---

## BOTTOM TAB BAR DESIGN

```
┌─────────────────────────────────────────────┐
│  [🏠]    [📊]    [➕]    [💡]    [👤]      │
│  Home   History  Scan  Insights Profile     │
└─────────────────────────────────────────────┘
```

**Visual Design:**
- Height: 80pt (standard iOS + safe area)
- Background: White with top border shadow
- Icons: SF Symbols, 24pt
- Labels: 10pt, medium weight
- Active: Primary color (orange), bold
- Inactive: Gray, regular
- Center tab (Scan): Elevated 56pt circular button
  - Orange gradient background
  - White "+" icon
  - Floats above tab bar

---

## IMPLEMENTATION STATUS

### ✅ COMPLETED (Home Screen)

**File:** `HomeView.swift`

**Components Implemented:**
1. Date Header Section (lines 238-275)
2. Status Widgets Row (lines 277-380)
   - Challenge status widget
   - Last scan widget
3. Hero Rings Section (lines 382-447)
   - 3 circular progress rings
   - Overall, Glow, Hydration scores
4. Latest Scan Summary Card (lines 449-504)
   - Dynamic title generation
   - Metric comparison logic
   - Special handling for first scan
5. View All Button (lines 896-916)
6. Conditional Rendering Logic (lines 121-181)

**Helper Functions Added:**
- `formatRelativeDate()` (lines 1292-1318)
- `formattedTodayDate` (lines 1320-1325)
- `generateSummaryTitle()` (lines 1327-1348)
- `generateSummaryText()` (lines 1350-1419)
- `startChallenge()` (lines 506-514)

**All Data Sources:** Real Core Data, NO placeholders

---

## TODO - Next Implementation Phases

### Phase 1: Bottom Tab Navigation
- Create TabView with 5 tabs
- Move HomeView to Tab 1
- Move ResultsHistoryView to Tab 2
- Keep scan flow in Tab 3
- Create placeholder Insights tab (Tab 4)
- Create placeholder Profile tab (Tab 5)

### Phase 2: Metric Detail Views
- Overall Score Detail
- Glow Score Detail
- Hydration Score Detail
- Tabbed interface with charts

### Phase 3: Enhanced Scan Detail View
- Scenic background
- Large hero ring
- Key metrics cards
- Insight card
- Timeline section
- Metrics breakdown with horizontal bars

### Phase 4: Insights Tab
- Personalized insight cards
- Recommendations engine
- Progress trends chart
- Educational content

### Phase 5: Profile Tab
- Profile header + photo upload
- Challenge progress card
- Achievements grid
- Stats section
- Settings links

---

## Design Reference

**Inspired by:** Fitness/health tracking apps (reference images provided)

**Key Design Principles:**
- Clean, minimal interface
- Data-driven insights
- Progress visualization
- Gamification elements
- Privacy-first approach
- No unnecessary emojis
- Professional, clinical feel

**Color Scheme:**
- Primary: Orange (#F2764A)
- Secondary: Blue (#5F6FE6)
- Accent: Yellow (#FCBC4E)
- Success: Green
- Background: Adaptive (light/dark mode)

**Typography:**
- Font: SF Pro Rounded
- Weights: Regular, Medium, Semibold, Bold
- Sizes: 10pt (labels) to 32pt (headings)

---

*Document created: 2025-01-10*
*Last updated: 2025-01-10*
