import SwiftUI

/// App 外觀主題模式 (跟隨系統、深色夜間、淺色日間)
public enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case dark = "dark"
    case light = "light"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .system: return "跟隨系統"
        case .dark: return "深色 (夜間極致)"
        case .light: return "淺色 (日間清晰)"
        }
    }
    
    public var iconName: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// 混合運動員全域語意色彩與美術規範 (遵循 Frontend Design 規範)
public struct HybridTheme {
    
    /// 依據當前 ColorScheme 動態返回適配顏色
    public static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
    
    // MARK: - 背景畫布與卡片
    /// 主背景畫布 (深色: 曜石黑 #090C10 | 淺色: 鈦金白 #F6F8FA)
    public static var background: Color {
        dynamic(light: "F6F8FA", dark: "090C10")
    }
    
    /// 卡片背景 (深色: #161B22 | 淺色: #FFFFFF)
    public static var cardBackground: Color {
        dynamic(light: "FFFFFF", dark: "161B22")
    }
    
    /// 次級卡片背景 / 點擊按鈕底色 (深色: #21262D | 淺色: #EAEEF2)
    public static var surfaceElevated: Color {
        dynamic(light: "EAEEF2", dark: "21262D")
    }
    
    /// 卡片邊框微弱線條 (深色: #30363D | 淺色: #D0D7DE)
    public static var cardBorder: Color {
        dynamic(light: "D0D7DE", dark: "30363D")
    }
    
    // MARK: - 文字與排版層次
    /// 主要高對比文字 (深色: #FFFFFF | 淺色: #1F2328)
    public static var textPrimary: Color {
        dynamic(light: "1F2328", dark: "FFFFFF")
    }
    
    /// 次要說明文字 (深色: #8B949E | 淺色: #656D76)
    public static var textSecondary: Color {
        dynamic(light: "656D76", dark: "8B949E")
    }
    
    /// 輔助弱標記文字 (深色: #6E7681 | 淺色: #8C959F)
    public static var textTertiary: Color {
        dynamic(light: "8C959F", dark: "6E7681")
    }
    
    // MARK: - 運動機能學功能色 (Adaptive Accents)
    /// 主色調 / 耐力有氧 / 訓練操作 (深色: 科技青藍 #58A6FF | 淺色: 專業深天藍 #0969DA)
    public static var accentBlue: Color {
        dynamic(light: "0969DA", dark: "58A6FF")
    }
    
    /// 恢復充足 / 準備就緒 / 成功 (深色: 活力翠綠 #3FB950 | 淺色: 運動草綠 #1A7F37)
    public static var successGreen: Color {
        dynamic(light: "1A7F37", dark: "3FB950")
    }
    
    /// 高能量 / 肌糖原補給 / 注意 (深色: 能量橙 #FF9F0A | 淺色: 衝刺焦橙 #BC4C00)
    public static var energyOrange: Color {
        dynamic(light: "BC4C00", dark: "FF9F0A")
    }
    
    /// 疲勞警告 / 傷病防線 / 刪除 (深色: 警戒紅 #F85149 | 淺色: 急性紅 #CF222E)
    public static var dangerRed: Color {
        dynamic(light: "CF222E", dark: "F85149")
    }
    
    /// 柔和黃色 / 警示 (深色: #D29922 | 淺色: #9A6700)
    public static var warningYellow: Color {
        dynamic(light: "9A6700", dark: "D29922")
    }
}
