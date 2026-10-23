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
    
    // MARK: - 背景畫布與卡片 (Apple System Grouped Palette)
    /// 主背景畫布 (深色: Apple 極致純黑 #000000 | 淺色: Apple 系統分組底色 #F2F2F7)
    public static var background: Color {
        dynamic(light: "F2F2F7", dark: "000000")
    }
    
    /// 卡片背景 (深色: Apple System Gray 6 #1C1C1E | 淺色: 極致純白 #FFFFFF)
    public static var cardBackground: Color {
        dynamic(light: "FFFFFF", dark: "1C1C1E")
    }
    
    /// 次級卡片背景 / 點擊按鈕底色 (深色: #2C2C2E | 淺色: #E5E5EA)
    public static var surfaceElevated: Color {
        dynamic(light: "E5E5EA", dark: "2C2C2E")
    }
    
    /// 卡片邊框微弱線條 (深色: #38383A | 淺色: #E5E5EA)
    public static var cardBorder: Color {
        dynamic(light: "E5E5EA", dark: "38383A")
    }
    
    // MARK: - 文字與排版層次 (Apple Typography Hierarchy)
    /// 主要高對比文字 (深色: #FFFFFF | 淺色: Apple 墨黑 #000000)
    public static var textPrimary: Color {
        dynamic(light: "000000", dark: "FFFFFF")
    }
    
    /// 次要說明文字 (深色: #8E8E93 | 淺色: Apple 次級標籤灰 #6C6C70)
    public static var textSecondary: Color {
        dynamic(light: "6C6C70", dark: "8E8E93")
    }
    
    /// 輔助弱標記文字 (深色: #636366 | 淺色: #8E8E93)
    public static var textTertiary: Color {
        dynamic(light: "8E8E93", dark: "636366")
    }
    
    // MARK: - Apple 經典運動機能色彩 (Apple Fitness & Health Vivid Accents)
    /// 主色調 / 耐力有氧 / 訓練操作 (深色: #0A84FF | 淺色: Apple 藍 #007AFF)
    public static var accentBlue: Color {
        dynamic(light: "007AFF", dark: "0A84FF")
    }
    
    /// 恢復充足 / 準備就緒 / 成功 (深色: #30D158 | 淺色: Apple Fitness 綠 #34C759)
    public static var successGreen: Color {
        dynamic(light: "34C759", dark: "30D158")
    }
    
    /// 高能量 / 肌糖原補給 / 注意 (深色: #FF9F0A | 淺色: Apple 運動熱量橙 #FF9500)
    public static var energyOrange: Color {
        dynamic(light: "FF9500", dark: "FF9F0A")
    }
    
    /// 疲勞警告 / 傷病防線 / 刪除 (深色: #FF453A | 淺色: Apple 系統紅 #FF3B30)
    public static var dangerRed: Color {
        dynamic(light: "FF3B30", dark: "FF453A")
    }
    
    /// 柔和黃色 / 警示 (深色: #FFD60A | 淺色: #F1A80A)
    public static var warningYellow: Color {
        dynamic(light: "F1A80A", dark: "FFD60A")
    }
    
    /// Apple Fitness 動態活動珊瑚粉 (深色: #FF375F | 淺色: #FF2D55)
    public static var coralPink: Color {
        dynamic(light: "FF2D55", dark: "FF375F")
    }
    
    /// Apple Health 科技水綠 / 有氧耐力 (深色: #63E6E2 | 淺色: #00C7BE)
    public static var healthTeal: Color {
        dynamic(light: "00C7BE", dark: "63E6E2")
    }
    
    /// Apple 複合力量紫色 (深色: #BF5AF2 | 淺色: #AF52DE)
    public static var activityPurple: Color {
        dynamic(light: "AF52DE", dark: "BF5AF2")
    }
}
