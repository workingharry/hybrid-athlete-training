# ADR 0006: Apple Watch Biomarker Engine & Readiness Architecture

- **Status**: Accepted
- **Deciders**: Systems Architect, Sports Science Lead, iOS Engineering
- **Date**: 2026-10-22

## Context
The legacy readiness engine evaluated readiness through a naive linear formula based on HRV SDNN, total sleep hours, and ACWR. This suffered from:
1. Absence of sensor noise floor considerations (triggering alerts on Apple Watch normal sensor variance).
2. Failure to distinguish nighttime resting autonomic state from daytime/mindfulness sympathetic spikes.
3. $\text{MAD} = 0$ division-by-zero vulnerability during cold starts ($N < 7$) or athletic resting HR stability.
4. Confounder baseline pollution (alcohol, illness, luteal phase shifting the 28-day reference pool).

## Decisions & Known Compromises

### 1. Known Compromises
- **SDNN instead of RMSSD**: Literature (Bellenger 2016) establishes $\ln(\text{RMSSD})$ as the standard for autonomic readiness. Because Apple Watch does not expose raw inter-beat (RR) intervals via HealthKit, we are constrained to `heartRateVariabilitySDNN`. To mitigate duration and non-stationarity issues:
  - We strictly filter SDNN samples to the nocturnal sleep window `[sleepOnset, finalWake]`.
  - We require $\ge 3$ valid SDNN samples per night; fewer samples degrades readiness to `BiomarkerOutcome.insufficientData(.tooFewSamples)`.
  - We perform geometric transformation ($\ln(\text{SDNN}_i)$ per sample first, then compute the nocturnal median).
  - We apply a 3-day exponential moving average to $\ln(\text{SDNN})$ deviations to avoid single-night over-sensitivity.
- **Apple RHR Opacity vs Nocturnal HR**: Apple's `restingHeartRate` is an opaque black box calculated across sedentary daytime/sleep periods. We extract sleep-window heart rate samples to compute `nocturnalSleepingHeartRateBpm` as the primary recovery metric, retaining Apple's official `restingHeartRate` as secondary context.

### 2. DTO at the Boundary (HealthKit Testability Seam)
Because `HKQuantitySample` and `HKCategorySample` have no public initializers and cannot be instantiated in unit tests, `HealthKitAdapter` must immediately translate all HealthKit entities to pure-Swift DTOs (`RawBiomarkerSampleDTO`) at the boundary. All filtering, sleep window intersection, mindfulness exclusion, and deduplication logic resides in a pure-Swift domain service operating strictly on DTOs, enabling 100% test coverage in `swift test`.

```swift
public struct RawBiomarkerSampleDTO: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        case sdnn, heartRate, restingHeartRate, respiratoryRate
        case sleep, mindfulSession, dietaryEnergy, activeEnergy
    }
    public let uuid: UUID
    public let kind: Kind
    public let value: Double?                 // unit-normalised
    public let sleepStage: SleepStage?        // inBed / awake / asleepUnspecified / core / deep / rem
    public let start: Date
    public let end: Date
    public let sourceBundleId: String
    public let sourceProductType: String?     // nil-safe
    public let isUserEntered: Bool
    public let timeZoneIdentifier: String?
}
```

### 3. Sleep Source Deduplication & watchOS Asynchrony
- Samples must match `sourceProductType?.hasPrefix("Watch") == true` to eliminate cross-device / iPhone in-bed collisions.
- Overlapping sleep intervals undergo union-merge before stage duration calculations.
- Eventual Consistency: When waking, watchOS often delays sleep stages by 15–30 minutes. The engine outputs `sleepStatus: .durationOnly` with `revision: 1`. When HealthKit observers signal finalized stages, the engine emits `sleepStatus: .finalized`, increments `revision: 2`, and updates the morning snapshot.

```swift
public enum SleepSyncStatus: String, Sendable, Codable {
    case durationOnly, finalized, finalizedDegraded
}

public enum BiomarkerOutcome: Sendable {
    case assessed(ReadinessAssessment)
    case calibrating(cleanDays: Int, partial: ReadinessAssessment?)
    case insufficientData(InsufficientReason)
}

public struct ReadinessAssessment: Sendable, Codable {
    public let dayKey: TrainingDayKey
    public let score: Int
    public let zone: ReadinessZone
    public let autonomic: AutonomicState
    public let confidence: MetricConfidence    // low / medium / high
    public let sleepStatus: SleepSyncStatus
    public let revision: Int
    public let algorithmVersion: String
}
```

### 4. Mathematical Guards
$$\text{Scale}_X = \max\left(1.4826 \times \text{MAD}_{28\text{d}}(X_{\text{clean}}),\ \sigma_{\min, X}\right)$$
- $\ln(\text{SDNN})$: $\sigma_{\min} = 0.05$.
- Resting HR: $\sigma_{\min} = 1.5\text{ bpm}$.
- Respiratory Rate: $\sigma_{\min} = 0.8\text{ rpm}$.
- Minimum baseline sample threshold: $N_{\min} = 14$ clean days. If $N < 14$, emit `BiomarkerOutcome.calibrating(cleanDays: N, partial: ...)`.

### 5. Baseline Reference Pool Masking
- Samples tagged `.alcohol` or `.illness` are excluded from the 28-day baseline reference pool.
- Samples tagged `.lutealPhase` have $+2.5\text{ bpm}$ subtracted before inclusion in the baseline pool.

### 6. Parallel-Run Validation Strategy
Before retiring `RobustZScoreCalculator`, both engines run in parallel in debug/internal builds, logging score differentials to verify predictive alignment.
