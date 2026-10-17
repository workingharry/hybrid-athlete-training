import Foundation

/// 阻力訓練經典動作庫 (4 大動作模式)
public struct ResistanceExerciseBank {
    
    public static let allExercises: [ResistanceExercise] = [
        // MARK: - 下肢膝主導 (Lower Quad)
        ResistanceExercise(
            name: "槓鈴後深蹲",
            englishName: "Barbell Back Squat",
            pattern: .lowerQuad,
            equipment: .barbell,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "足弓三點踩實，膝蓋對齊第二腳趾，軀幹維持腹壓緊繃。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRepRange: "3-5 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "槓鈴前深蹲",
            englishName: "Barbell Front Squat",
            pattern: .lowerQuad,
            equipment: .barbell,
            primaryMuscles: ["股四頭肌", "核心肌群"],
            techniqueCues: "手肘高抬，維持上背直立，深蹲至大腿低於水平。",
            defaultSets: 3,
            defaultReps: 8,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "保加利亞分腿蹲",
            englishName: "Bulgarian Split Squat",
            pattern: .lowerQuad,
            equipment: .dumbbell,
            primaryMuscles: ["股四頭肌", "臀大肌", "臀中肌"],
            techniqueCues: "後腳腳背置於臥推椅，前腳膝蓋不內扣，垂直下沉。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "45度腿推機",
            englishName: "Leg Press",
            pattern: .lowerQuad,
            equipment: .machine,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "下背緊貼靠墊，膝蓋屈曲約 90 度，推起時膝關節不鎖死。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRepRange: "3-4 組 x 10-15 次"
        ),
        ResistanceExercise(
            name: "啞鈴酒杯深蹲",
            englishName: "Goblet Squat",
            pattern: .lowerQuad,
            equipment: .dumbbell,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "雙手捧啞鈴於胸前，下蹲手肘微觸膝蓋內側，保持胸腔挺起。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRepRange: "3-4 組 x 10-15 次"
        ),
        
        // MARK: - 下肢髖主導 (Lower Posterior)
        ResistanceExercise(
            name: "傳統槓鈴硬舉",
            englishName: "Conventional Deadlift",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["臀大肌", "膕繩肌", "豎脊肌", "背闊肌"],
            techniqueCues: "槓鈴貼小腿，臀部微高於膝，腿蹬地帶動髖伸展。",
            defaultSets: 4,
            defaultReps: 5,
            defaultRepRange: "3-5 組 x 3-6 次"
        ),
        ResistanceExercise(
            name: "羅馬尼亞硬舉 (RDL)",
            englishName: "Romanian Deadlift",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["膕繩肌", "臀大肌"],
            techniqueCues: "微屈膝維持小腿垂直，髖向後推感受大腿後側拉緊，背部平直。",
            defaultSets: 3,
            defaultReps: 8,
            defaultRepRange: "3-4 組 x 8-10 次"
        ),
        ResistanceExercise(
            name: "六角槓硬舉",
            englishName: "Trap Bar Deadlift",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["臀大肌", "股四頭肌", "膕繩肌"],
            techniqueCues: "握把對齊身體重心，中立位直上直下，脊椎剪力較傳統槓低。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRepRange: "3-4 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "槓鈴臀推",
            englishName: "Barbell Hip Thrust",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["臀大肌"],
            techniqueCues: "肩胛骨下角靠凳，頂點收縮臀部使大腿與軀幹成一直線，收下巴。",
            defaultSets: 4,
            defaultReps: 10,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "單腳啞鈴 RDL",
            englishName: "Single-Leg RDL",
            pattern: .lowerPosterior,
            equipment: .dumbbell,
            primaryMuscles: ["膕繩肌", "臀中肌"],
            techniqueCues: "支撐腳微屈，後腳與軀幹成一直線向後延伸，骨盆不翻轉。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3 組 x 8-12 次"
        ),

        // MARK: - 上半身推 (Upper Push)
        ResistanceExercise(
            name: "平板槓鈴臥推",
            englishName: "Barbell Bench Press",
            pattern: .upperPush,
            equipment: .barbell,
            primaryMuscles: ["胸大肌", "三角肌前束", "肱三頭肌"],
            techniqueCues: "肩胛後收下沉，槓鈴下落至胸骨劍突，推起呼氣。",
            defaultSets: 4,
            defaultReps: 8,
            defaultRepRange: "3-5 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "上斜啞鈴臥推",
            englishName: "Incline DB Bench Press",
            pattern: .upperPush,
            equipment: .dumbbell,
            primaryMuscles: ["胸大肌上束", "三角肌前束"],
            techniqueCues: "椅背約 30 度，小臂全程垂直地面，推至頂峰不過度撞鈴。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "站姿槓鈴肩推 (OHP)",
            englishName: "Overhead Press",
            pattern: .upperPush,
            equipment: .barbell,
            primaryMuscles: ["三角肌", "肱三頭肌", "核心"],
            techniqueCues: "夾緊臀部與核心，槓推過頭頂後頭部微前送，鎖定肩胛關節。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRepRange: "3-4 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "雙槓臂屈伸 (Dips)",
            englishName: "Parallel Bar Dips",
            pattern: .upperPush,
            equipment: .bodyweight,
            primaryMuscles: ["胸大肌下束", "肱三頭肌"],
            techniqueCues: "軀幹微前傾側重胸肌，小臂保持垂直，下沉至手肘約 90 度。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "滑輪三頭下壓",
            englishName: "Cable Triceps Pushdown",
            pattern: .upperPush,
            equipment: .cable,
            primaryMuscles: ["肱三頭肌"],
            techniqueCues: "大臂夾緊軀幹兩側固定，小臂伸展下壓至完全收縮。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRepRange: "3 組 x 10-15 次"
        ),

        // MARK: - 上半身拉 (Upper Pull)
        ResistanceExercise(
            name: "引體向上 (正手/反手)",
            englishName: "Pull-Ups / Chin-Ups",
            pattern: .upperPull,
            equipment: .bodyweight,
            primaryMuscles: ["背闊肌", "二頭肌", "菱形肌"],
            techniqueCues: "沉肩啟動背部發力，下巴過槓，頂部擠壓肩胛骨，離心慢放。",
            defaultSets: 4,
            defaultReps: 8,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "俯身槓鈴划船",
            englishName: "Bent-Over Barbell Row",
            pattern: .upperPull,
            equipment: .barbell,
            primaryMuscles: ["背闊肌", "菱形肌", "中下斜方肌"],
            techniqueCues: "俯身約 45 度，背平直，手肘貼近軀幹拉向腹部肚臍方向。",
            defaultSets: 4,
            defaultReps: 8,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "高位滑輪下拉",
            englishName: "Lat Pulldown",
            pattern: .upperPull,
            equipment: .cable,
            primaryMuscles: ["背闊肌", "大圓肌"],
            techniqueCues: "挺胸微後仰，肩胛下沉下拉橫槓至鎖骨下方，不借助爆發力。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "單臂啞鈴划船",
            englishName: "One-Arm Dumbbell Row",
            pattern: .upperPull,
            equipment: .dumbbell,
            primaryMuscles: ["背闊肌", "菱形肌"],
            techniqueCues: "單膝支撐臥推椅，脊椎中立，手肘向臀部方向弧線拉起。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRepRange: "3 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "滑輪面拉 (Face Pull)",
            englishName: "Cable Face Pull",
            pattern: .upperPull,
            equipment: .cable,
            primaryMuscles: ["三角肌後束", "旋轉肌袖", "斜方肌"],
            techniqueCues: "滑輪調至眼睛高度，向面部拉開繩索同時外旋小臂，強化肩部健康。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRepRange: "3 組 x 12-15 次"
        )
    ]
    
    /// 依部位獲取動作清單
    public static func exercises(for pattern: MovementPattern) -> [ResistanceExercise] {
        return allExercises.filter { $0.pattern == pattern }
    }
    
    /// 模糊搜尋
    public static func search(query: String) -> [ResistanceExercise] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return allExercises }
        let lower = query.lowercased()
        return allExercises.filter {
            $0.name.lowercased().contains(lower) ||
            $0.englishName.lowercased().contains(lower) ||
            $0.primaryMuscles.joined().lowercased().contains(lower) ||
            $0.equipment.displayName.lowercased().contains(lower)
        }
    }
}
