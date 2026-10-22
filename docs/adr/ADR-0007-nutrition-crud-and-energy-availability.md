# ADR 0007: Reactive Nutrition CRUD, Energy Availability & Training Day Architecture

- **Status**: Accepted
- **Deciders**: Systems Architect, Sports Science Lead, iOS Engineering
- **Date**: 2026-10-22

## Context
Nutrition tracking in the app was previously an ephemeral accumulator in UI state, lacking CRUD capabilities (delete, edit, review). In addition, Energy Availability (EA) was a static hardcoded number. Early attempts to make EA dynamic suffered from:
1. False RED-S alarms due to single-day missed meals or delayed logging.
2. EEE estimation errors on wrist PPG during heavy strength training ($\pm 20-30\%$).
3. Misclassifying total daily active energy (including NEAT: walking, household chores) as exercise expenditure.
4. Concurrency issues between background HealthKit updates and SwiftData on the main actor.

## Decisions & Known Compromises

### 1. Known Compromises & IOC REDs CAT2 Alignment
- Per the 2023 IOC Consensus Statement (Mountjoy et al., *Br J Sports Med*, PMID: 37752011), field-based EA calculation carries substantial measurement uncertainty and must **never** be used as an automated diagnostic tool or sole criterion for training restriction.
- The app presents Energy Availability as an **exploratory screening indicator with uncertainty bounds**, complying with App Store Guideline 1.4.1 (no medical diagnostic claims).

```swift
public struct EAEstimate: Sendable, Codable {
    public enum State: String, Sendable, Codable {
        case insufficientDays // fewer than 4 valid days
        case estimated
    }
    public let state: State
    public let point: Double?       // kcal/kg FFM
    public let lower: Double?       // -5 kcal/kg FFM uncertainty bound
    public let upper: Double?       // +5 kcal/kg FFM uncertainty bound
    public let completeDays: Int
    public let excludedDays: Int
}
```

### 2. Training Day Boundary (4:00 AM Rollover)
Athletes frequently consume post-workout meals, recovery shakes, or hydration past midnight. A strict 00:00 calendar cutoff breaks meal attribution.
- The **Training Day** rolls over at **4:00 AM local time** (`TrainingDayKey`).
- Entries logged between 00:00 and 03:59 belong to the previous training day's logbook.
- The app listens for `NSCalendarDayChanged` to refresh date predicates dynamically.

### 3. Nutrition Completeness Gate & Intermittent Fasting (IF/OMAD)
To prevent incomplete meal logs from dragging down rolling EA:
- A day is classified as `.complete` if:
  1. Intake $\ge 0.75 \times \text{BMR}$ **AND** at least 2 meal slots are logged; OR
  2. The user explicitly toggles "Day Completed / Fasting" (`isDayFinalized = true`); OR
  3. The user has enabled "Intermittent Fasting / OMAD" in athlete settings.
- Incomplete days are **excluded from the 7-day rolling EA denominator** (`excludedDays`) rather than treated as a zero/starvation day.
- If fewer than 4 complete days exist in the past 7 days, EA is marked `EAEstimate.State.insufficientDays`.

### 4. EEE vs NEAT Disaggregation
$$\text{EEE}_{\text{effective}} = \sum \text{Workout Active Calories} + 0.35 \times \max(0, \text{Total Active Calories} - \sum \text{Workout Active Calories})$$
- Fat-Free Mass (FFM) is sourced from HealthKit `HKQuantityTypeIdentifier.leanBodyMass` when available, falling back to Katch-McArdle formula based on profile body fat %.

### 5. SwiftData `@ModelActor` Architecture
- Background HealthKit sync and multi-day rolling EA aggregation are executed on a dedicated `@ModelActor` (`NutritionPersistenceActor`).
- The UI layer (`NutritionDetailSheet`, `NutritionLogbookView`) observes a lightweight `@Query` filtered to the active training day.
- Single entries support swipe-to-delete with `UIImpactFeedbackGenerator` and tap-to-edit prefilling `PreciseNutritionEntrySheet`.
