import Foundation

/// 跑步單次運動學與生物力學樣本
public struct RunningMechanicsSample: Sendable, Codable, Equatable, Identifiable {
    public var id: String { "\(date.timeIntervalSince1970)_\(Int(runningPowerWatts ?? 0))" }
    
    public let date: Date
    public let durationSeconds: TimeInterval
    public let averageSpeedMetersPerSecond: Double         // 配速換算之速度 (m/s)
    public let groundContactTimeMs: Double?                // 觸地時間 (ms) - HKQuantityTypeIdentifier.runningGroundContactTime
    public let verticalOscillationCm: Double?              // 垂直振幅 (cm) - HKQuantityTypeIdentifier.runningVerticalOscillation
    public let runningPowerWatts: Double?                  // 跑步機械功率 (W) - HKQuantityTypeIdentifier.runningPower
    public let strideLengthMeters: Double?                 // 步幅長度 (m) - HKQuantityTypeIdentifier.runningStrideLength
    public let cadenceStepsPerMinute: Double?              // 步頻 (spm)
    public let athleteBodyMassKg: Double                   // 運動員體重 (kg)
    public let estimatedLegLengthMeters: Double            // 腿長 (m, 預設為 身高 * 0.53)
    
    public init(
        date: Date,
        durationSeconds: TimeInterval,
        averageSpeedMetersPerSecond: Double,
        groundContactTimeMs: Double?,
        verticalOscillationCm: Double?,
        runningPowerWatts: Double?,
        strideLengthMeters: Double?,
        cadenceStepsPerMinute: Double? = nil,
        athleteBodyMassKg: Double = 70.0,
        estimatedLegLengthMeters: Double = 0.90
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.groundContactTimeMs = groundContactTimeMs
        self.verticalOscillationCm = verticalOscillationCm
        self.runningPowerWatts = runningPowerWatts
        self.strideLengthMeters = strideLengthMeters
        self.cadenceStepsPerMinute = cadenceStepsPerMinute
        self.athleteBodyMassKg = athleteBodyMassKg
        self.estimatedLegLengthMeters = estimatedLegLengthMeters
    }
    
    /// 生物力學數據是否具備計算剛性與效率的充足有效性
    public var isValidBiomechanicsSample: Bool {
        guard let gct = groundContactTimeMs, let vo = verticalOscillationCm, let stride = strideLengthMeters else {
            return false
        }
        return gct > 120.0 && gct < 450.0 && vo > 2.0 && vo < 25.0 && stride > 0.4 && averageSpeedMetersPerSecond > 1.5
    }
    
    /// 垂直移動比 (Vertical Ratio % = 垂直振幅 / 步幅)，越低代表越具跑步經濟性 (< 7.0% 為精英，8-10% 為普通)
    public var verticalRatioPercent: Double? {
        guard let vo = verticalOscillationCm, let stride = strideLengthMeters, stride > 0 else { return nil }
        return ((vo / 100.0) / stride) * 100.0
    }
    
    /// 步期 (Step Period in seconds)
    public var stepPeriodSeconds: Double? {
        if let cad = cadenceStepsPerMinute, cad > 0 {
            return 60.0 / cad
        } else if let stride = strideLengthMeters, averageSpeedMetersPerSecond > 0 {
            return stride / averageSpeedMetersPerSecond
        }
        return nil
    }
    
    /// Morin 彈簧質量模型 (Spring-Mass Model) 下肢垂直剛性 (Vertical Stiffness k_vert in kN/m)
    /// 公式：k_vert = F_max / Δy, 其中 F_max = m * g * (π/2) * (t_aerial/t_c + 1)
    public var verticalStiffnessKiloNewtonsPerMeter: Double? {
        guard let gctMs = groundContactTimeMs, let voCm = verticalOscillationCm, let stepPeriod = stepPeriodSeconds else {
            return nil
        }
        let tc = gctMs / 1000.0 // 觸地時間 (s)
        let deltaY = voCm / 100.0 // 質心垂直位移 (m)
        guard tc > 0, deltaY > 0, stepPeriod > tc else { return nil }
        
        let ta = stepPeriod - tc // 騰空時間 (s)
        let g = 9.81
        let fMax = athleteBodyMassKg * g * (.pi / 2.0) * ((ta / tc) + 1.0)
        let kVert = (fMax / deltaY) / 1000.0 // 轉為 kN/m
        return (kVert.isFinite && kVert > 5.0 && kVert < 80.0) ? kVert : nil
    }
    
    /// 機械跑步經濟性 (Running Economy = 功率 / 速度，W / (m/s))，每前進 1 m/s 所消耗之瓦特
    public var costOfPowerWattsPerSpeed: Double? {
        guard let p = runningPowerWatts, averageSpeedMetersPerSecond > 0 else { return nil }
        return p / averageSpeedMetersPerSecond
    }
}

/// 下肢牽張縮短循環 (Stretch-Shortening Cycle, SSC) 疲勞狀態
public enum SSCFatigueStatus: String, Sendable, Codable, Equatable {
    case nominal                // 剛性與力學健康，無明顯 SSC 衰退
    case mildStiffnessLoss      // 輕度剛性衰減 (重訓後暫時性延遲微創)
    case severeDecoupled        // 重度神經肌肉疲勞/剛性衰減 (傷膝/傷腱高風險)
    case insufficientBaseline   // 歷史跑步樣本不足，校準中
}

/// 跑步力學綜合評估輸出
public struct RunningMechanicsAssessment: Sendable, Codable, Equatable {
    public let status: SSCFatigueStatus
    public let groundContactTimeDeltaMs: Double?         // 相比個人同配速基準之 GCT 殘差 (ms)
    public let verticalStiffnessLossPercent: Double?     // 下肢剛性衰減比例 (%)
    public let runningEconomyDegraded: Bool              // 機械功率代償是否超標
    public let isSquatLegDayDecoupled: Bool              // 是否為深蹲/腿部重訓後下肢專屬衰竭
    public let injuryMitigationDirectives: [String]      // 具體防傷行動指令
    
    public init(
        status: SSCFatigueStatus,
        groundContactTimeDeltaMs: Double? = nil,
        verticalStiffnessLossPercent: Double? = nil,
        runningEconomyDegraded: Bool = false,
        isSquatLegDayDecoupled: Bool = false,
        injuryMitigationDirectives: [String] = []
    ) {
        self.status = status
        self.groundContactTimeDeltaMs = groundContactTimeDeltaMs
        self.verticalStiffnessLossPercent = verticalStiffnessLossPercent
        self.runningEconomyDegraded = runningEconomyDegraded
        self.isSquatLegDayDecoupled = isSquatLegDayDecoupled
        self.injuryMitigationDirectives = injuryMitigationDirectives
    }
}
