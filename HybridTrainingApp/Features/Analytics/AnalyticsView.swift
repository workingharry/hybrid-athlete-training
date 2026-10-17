import SwiftUI
import Charts
import HybridTrainingCore
import HybridTrainingStorage

/// Version 2: 生理恢復趨勢與運動負荷分析中心 (AnalyticsView)
public struct AnalyticsView: View {
    let healthKitAdapter: HealthKitAdapter
    
    @State private var hrvHistory: [HRVDataPoint] = []
    @State private var acwrHistory: [ACWRDataPoint] = []
    @State private var sleepHistory: [SleepDataPoint] = []
    @State private var isLoading: Bool = true
    
    public init(healthKitAdapter: HealthKitAdapter = HealthKitAdapter()) {
        self.healthKitAdapter = healthKitAdapter
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "090C10").ignoresSafeArea()
                
                if isLoading {
                    ProgressView("載入 Apple Watch 生理與負荷趨勢...")
                        .tint(Color(hex: "58A6FF"))
                        .foregroundColor(Color(hex: "8B949E"))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 1. 14 天夜間 HRV 走勢圖
                            hrvTrendCard
                            
                            // 2. 急慢性負荷比率 (ACWR) 監控卡片
                            acwrCard
                            
                            // 3. 睡眠恢復時長趨勢
                            sleepCard
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("生理與負荷趨勢")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadHistoricalAnalytics()
            }
            .refreshable {
                await loadHistoricalAnalytics()
            }
        }
    }
    
    // MARK: - 14 天 HRV 走勢卡片
    private var hrvTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("14 天夜間 HRV (SDNN) 走勢", systemImage: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "58A6FF"))
                Spacer()
                if let last = hrvHistory.last {
                    Text("\(Int(last.value)) ms")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text("以 14 天穩健中位數為基準，當前數值顯著低於正常帶時觸發疲勞退避機制。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8B949E"))
            
            if !hrvHistory.isEmpty {
                Chart {
                    ForEach(hrvHistory) { item in
                        LineMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("HRV", item.value)
                        )
                        .foregroundStyle(Color(hex: "58A6FF"))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("HRV", item.value)
                        )
                        .foregroundStyle(item.value < item.median * 0.75 ? Color(hex: "F85149") : Color(hex: "3FB950"))
                    }
                    
                    if let median = hrvHistory.last?.median {
                        RuleMark(y: .value("中位數", median))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color(hex: "8B949E"))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("中位數: \(Int(median))ms")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color(hex: "30363D"))
                        AxisValueLabel() {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)ms")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "8B949E"))
                    }
                }
                .frame(height: 180)
            } else {
                Text("尚無足夠之 HealthKit HRV 紀錄")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8B949E"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 120)
            }
        }
        .padding(16)
        .background(Color(hex: "161B22"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }
    
    // MARK: - ACWR 監控卡片
    private var acwrCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("急慢性運動負荷比 (ACWR)", systemImage: "gauge.with.needle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "3FB950"))
                Spacer()
                if let last = acwrHistory.last {
                    Text(String(format: "%.2f", last.ratio))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(acwrColor(last.ratio))
                }
            }
            
            Text("綠色區域 (0.80～1.30) 為最佳適應甜蜜區；超過 1.50 進入負荷驟升警戒區。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8B949E"))
            
            if !acwrHistory.isEmpty {
                Chart {
                    ForEach(acwrHistory) { item in
                        LineMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("ACWR", item.ratio)
                        )
                        .foregroundStyle(Color(hex: "3FB950"))
                        
                        PointMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("ACWR", item.ratio)
                        )
                        .foregroundStyle(acwrColor(item.ratio))
                    }
                    
                    RuleMark(y: .value("危險上限", 1.50))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "F85149"))
                    
                    RuleMark(y: .value("甜蜜區間上限", 1.30))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .foregroundStyle(Color(hex: "D29922"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color(hex: "30363D"))
                        AxisValueLabel() {
                            if let doubleVal = value.as(Double.self) {
                                Text(String(format: "%.1f", doubleVal))
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 4)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "8B949E"))
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(Color(hex: "161B22"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }
    
    // MARK: - 睡眠趨勢卡片
    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("夜間睡眠時長 (Sleep)", systemImage: "bed.double.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "D29922"))
                Spacer()
                if let last = sleepHistory.last {
                    Text(String(format: "%.1f 小時", last.hours))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            if !sleepHistory.isEmpty {
                Chart {
                    ForEach(sleepHistory) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("時長", item.hours)
                        )
                        .foregroundStyle(item.hours >= 7.0 ? Color(hex: "3FB950") : Color(hex: "D29922"))
                    }
                    
                    RuleMark(y: .value("標準線", 7.0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color(hex: "8B949E"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel() {
                            if let doubleVal = value.as(Double.self) {
                                Text("\(Int(doubleVal))h")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "8B949E"))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "8B949E"))
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(16)
        .background(Color(hex: "161B22"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "30363D"), lineWidth: 1)
        )
    }
    
    private func acwrColor(_ ratio: Double) -> Color {
        if ratio > 1.50 { return Color(hex: "F85149") }
        if ratio > 1.30 { return Color(hex: "D29922") }
        if ratio >= 0.80 { return Color(hex: "3FB950") }
        return Color(hex: "58A6FF")
    }
    
    // MARK: - 歷史資料運算
    private func loadHistoricalAnalytics() async {
        let calendar = Calendar.current
        let now = Date()
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        
        // 抓取真實 HealthKit 數據
        let workouts = (try? await healthKitAdapter.fetchWorkouts(from: sixtyDaysAgo, to: now)) ?? []
        
        var points: [HRVDataPoint] = []
        var sleepPoints: [SleepDataPoint] = []
        var acwrPoints: [ACWRDataPoint] = []
        
        // 整理最近 14 天
        for dayOffset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // 取得該日快照
            let snapshot = (try? await healthKitAdapter.fetchPhysiologicalSnapshot(date: date))
            let hrvVal = snapshot?.hrvTodayMs ?? 55.0
            let medianVal = snapshot?.hrv14dMedianMs ?? 60.0
            let sleepH = snapshot?.sleepDurationHours ?? 7.5
            
            points.append(HRVDataPoint(date: date, value: hrvVal, median: medianVal))
            sleepPoints.append(SleepDataPoint(date: date, hours: sleepH))
            
            // 計算當天 ACWR
            let acwrResult = ACWRCalculator.calculate(
                sessions: workouts,
                referenceDate: date,
                calendar: calendar,
                baselineCTL: nil,
                configuration: .default
            )
            acwrPoints.append(ACWRDataPoint(date: date, ratio: acwrResult.acwr))
        }
        
        await MainActor.run {
            self.hrvHistory = points
            self.sleepHistory = sleepPoints
            self.acwrHistory = acwrPoints
            self.isLoading = false
        }
    }
}

// MARK: - 圖表資料模型
struct HRVDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let median: Double
}

struct ACWRDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let ratio: Double
}

struct SleepDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
}
