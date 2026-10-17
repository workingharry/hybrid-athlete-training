# 0001. WorkoutKit-First 代替獨立 watchOS 應用程式

## 狀態
Accepted

## 背景與決策
混合訓練系統需要將結構化跑步課表（含熱身、主區間與心率警示）推送至使用者的 Apple Watch，並在跑者跑步期間提供即時心率與震動提示。我們決定採用 iOS 17+ 原生 `WorkoutKit` API 直接將 `WorkoutPlan` 排程至手錶原生「體能訓練」App，完全不開發獨立的 watchOS 應用程式。

## 原因與取捨
獨立開發與維護 watchOS App 伴隨極高的雙端同步、連線重試、背景續航限制與架構維護成本；而 WorkoutKit 原生方案能讓使用者在零維護成本下，無縫享有 Apple Watch 官方體能訓練的常亮顯示 (Always-On Display)、最高精確度的觸覺震動警示與原生健康生態整合。
