import Foundation

/// 阻力訓練經典動作庫 (4 大動作模式，精確區分自由重量與固定器械)
public struct ResistanceExerciseBank {
    
    public static let allExercises: [ResistanceExercise] = [
        // MARK: - 下肢膝主導 (Lower Quad - Squat Variations)
        ResistanceExercise(
            name: "槓鈴後深蹲",
            englishName: "Barbell Back Squat",
            pattern: .lowerQuad,
            equipment: .barbell,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "足弓三點踩實，膝蓋對齊第二腳趾，軀幹維持腹壓緊繃。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRestSeconds: 120,
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
            defaultRestSeconds: 120,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "保加利亞分腿蹲 (啞鈴)",
            englishName: "Bulgarian Split Squat (Dumbbell)",
            pattern: .lowerQuad,
            equipment: .dumbbell,
            primaryMuscles: ["股四頭肌", "臀大肌", "臀中肌"],
            techniqueCues: "後腳腳背置於臥推椅，前腳膝蓋不內扣，垂直下沉。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "徒手單腳蹲 (手槍蹲)",
            englishName: "Single-Leg Pistol Squat",
            pattern: .lowerQuad,
            equipment: .bodyweight,
            primaryMuscles: ["股四頭肌", "臀大肌", "踝關節穩定肌"],
            techniqueCues: "非支撐腳前伸，核心緊收平穩下沉至髖低於膝，推地站起。",
            defaultSets: 3,
            defaultReps: 6,
            defaultRestSeconds: 90,
            defaultRepRange: "3 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "45度腿推機 (器械)",
            englishName: "45° Leg Press Machine",
            pattern: .lowerQuad,
            equipment: .machine,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "下背緊貼靠墊，膝蓋屈曲約 90 度，推起時膝關節不鎖死，負重大於自由槓。",
            defaultSets: 4,
            defaultReps: 12,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 10-15 次"
        ),
        ResistanceExercise(
            name: "器械腿部伸展機",
            englishName: "Leg Extension Machine",
            pattern: .lowerQuad,
            equipment: .machine,
            primaryMuscles: ["股四頭肌"],
            techniqueCues: "靠緊座椅，頂峰收縮停頓 1 秒，慢速離心下放。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRestSeconds: 60,
            defaultRepRange: "3 組 x 10-15 次"
        ),
        ResistanceExercise(
            name: "啞鈴酒杯深蹲",
            englishName: "Goblet Squat (Dumbbell)",
            pattern: .lowerQuad,
            equipment: .dumbbell,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "雙手捧啞鈴於胸前，下蹲手肘微觸膝蓋內側，保持胸腔挺起。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRestSeconds: 60,
            defaultRepRange: "3-4 組 x 10-15 次"
        ),
        ResistanceExercise(
            name: "徒手自重深蹲",
            englishName: "Air Squat",
            pattern: .lowerQuad,
            equipment: .bodyweight,
            primaryMuscles: ["股四頭肌", "臀大肌"],
            techniqueCues: "雙腳微寬於肩，雙手前伸平衡，下蹲至髖關節折疊平行。",
            defaultSets: 3,
            defaultReps: 20,
            defaultRestSeconds: 45,
            defaultRepRange: "3-4 組 x 15-25 次"
        ),
        
        // MARK: - 下肢髖主導 (Lower Posterior - Hinge & Hamstrings)
        ResistanceExercise(
            name: "傳統槓鈴硬舉",
            englishName: "Conventional Barbell Deadlift",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["臀大肌", "膕繩肌", "豎脊肌", "背闊肌"],
            techniqueCues: "槓鈴貼小腿，臀部微高於膝，腿蹬地帶動髖伸展。",
            defaultSets: 4,
            defaultReps: 5,
            defaultRestSeconds: 150,
            defaultRepRange: "3-5 組 x 3-6 次"
        ),
        ResistanceExercise(
            name: "羅馬尼亞硬舉 (RDL)",
            englishName: "Barbell Romanian Deadlift",
            pattern: .lowerPosterior,
            equipment: .barbell,
            primaryMuscles: ["膕繩肌", "臀大肌"],
            techniqueCues: "微屈膝維持小腿垂直，髖向後推感受大腿後側拉緊，背部平直。",
            defaultSets: 3,
            defaultReps: 8,
            defaultRestSeconds: 90,
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
            defaultRestSeconds: 120,
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
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "單腳啞鈴 RDL",
            englishName: "Single-Leg Dumbbell RDL",
            pattern: .lowerPosterior,
            equipment: .dumbbell,
            primaryMuscles: ["膕繩肌", "臀中肌"],
            techniqueCues: "支撐腳微屈，後腳與軀幹成一直線向後延伸，骨盆不翻轉。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 60,
            defaultRepRange: "3 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "器械腿後勾 (俯臥/坐姿)",
            englishName: "Lying Leg Curl Machine",
            pattern: .lowerPosterior,
            equipment: .machine,
            primaryMuscles: ["膕繩肌"],
            techniqueCues: "骨盆緊貼墊面，膕繩肌發力勾起滾軸，頂峰收縮後緩慢離心下落。",
            defaultSets: 3,
            defaultReps: 12,
            defaultRestSeconds: 60,
            defaultRepRange: "3-4 組 x 10-15 次"
        ),
        ResistanceExercise(
            name: "站姿提踵 (小腿)",
            englishName: "Standing Calf Raise",
            pattern: .lowerPosterior,
            equipment: .machine,
            primaryMuscles: ["腓腸肌", "比目魚肌"],
            techniqueCues: "前腳掌站於踏板邊緣，充分伸展腳踝後用力踮起至最高點。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRestSeconds: 45,
            defaultRepRange: "3 組 x 12-20 次"
        ),

        // MARK: - 上半身推 (Upper Push & Shoulder External Rotation)
        ResistanceExercise(
            name: "標準伏地挺身",
            englishName: "Standard Push-up",
            pattern: .upperPush,
            equipment: .bodyweight,
            primaryMuscles: ["胸大肌", "三角肌前束", "肱三頭肌", "核心"],
            techniqueCues: "身體成一直線，手肘與軀幹呈約 45 度角，下沉至胸微觸地面。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRestSeconds: 60,
            defaultRepRange: "3-4 組 x 12-20 次"
        ),
        ResistanceExercise(
            name: "平板槓鈴臥推",
            englishName: "Barbell Bench Press",
            pattern: .upperPush,
            equipment: .barbell,
            primaryMuscles: ["胸大肌", "三角肌前束", "肱三頭肌"],
            techniqueCues: "肩胛後收下沉，槓鈴下落至胸骨劍突，推起呼氣。",
            defaultSets: 4,
            defaultReps: 8,
            defaultRestSeconds: 120,
            defaultRepRange: "3-5 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "坐姿器械推胸 (器械)",
            englishName: "Seated Chest Press Machine",
            pattern: .upperPush,
            equipment: .machine,
            primaryMuscles: ["胸大肌", "肱三頭肌"],
            techniqueCues: "調整座椅高度使握把對齊胸部中段，導軌安全固定，適合力竭衝刺。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
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
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "站姿槓鈴肩推 (OHP)",
            englishName: "Overhead Press (Barbell)",
            pattern: .upperPush,
            equipment: .barbell,
            primaryMuscles: ["三角肌", "肱三頭肌", "核心"],
            techniqueCues: "夾緊臀部與核心，槓推過頭頂後頭部微前送，鎖定肩胛關節。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRestSeconds: 120,
            defaultRepRange: "3-4 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "坐姿器械肩推 (器械)",
            englishName: "Seated Shoulder Press Machine",
            pattern: .upperPush,
            equipment: .machine,
            primaryMuscles: ["三角肌前中束", "肱三頭肌"],
            techniqueCues: "背部貼緊靠墊，手肘向下不超伸，直上直下推起。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "滑輪肩外旋 (肩袖強化)",
            englishName: "Cable Shoulder External Rotation",
            pattern: .upperPush,
            equipment: .cable,
            primaryMuscles: ["棘下肌", "小圓肌", "肩袖肌群"],
            techniqueCues: "手肘夾角 90 度並緊貼軀幹，手握滑輪向外旋轉，控制離心回放，預防跑步擺臂肩夾擠。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRestSeconds: 45,
            defaultRepRange: "3 組 x 12-15 次"
        ),
        ResistanceExercise(
            name: "啞鈴肩外旋 (側臥/俯臥)",
            englishName: "Dumbbell External Rotation",
            pattern: .upperPush,
            equipment: .dumbbell,
            primaryMuscles: ["棘下肌", "小圓肌"],
            techniqueCues: "側臥或俯臥於斜凳，手肘固定為軸心，輕重量外旋小臂感受深層肩袖發力。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRestSeconds: 45,
            defaultRepRange: "3 組 x 12-15 次"
        ),
        ResistanceExercise(
            name: "啞鈴側平舉",
            englishName: "Dumbbell Lateral Raise",
            pattern: .upperPush,
            equipment: .dumbbell,
            primaryMuscles: ["三角肌中束"],
            techniqueCues: "手肘微屈，向身體斜前方約 30 度平舉至水平，沉肩不聳肩。",
            defaultSets: 4,
            defaultReps: 15,
            defaultRestSeconds: 60,
            defaultRepRange: "3-4 組 x 12-15 次"
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
            defaultRestSeconds: 90,
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
            defaultRestSeconds: 60,
            defaultRepRange: "3 組 x 10-15 次"
        ),

        // MARK: - 上半身拉 (Upper Pull & Shoulder Pulls)
        ResistanceExercise(
            name: "槓鈴高拉 (肩部高提拉)",
            englishName: "Barbell High Pull",
            pattern: .upperPull,
            equipment: .barbell,
            primaryMuscles: ["三角肌中後束", "斜方肌", "上背肌群"],
            techniqueCues: "屈髖微屈膝，雙腿爆發蹬伸帶動槓鈴垂直向上拉至胸口高度，手肘引領向上。",
            defaultSets: 4,
            defaultReps: 6,
            defaultRestSeconds: 120,
            defaultRepRange: "3-4 組 x 5-8 次"
        ),
        ResistanceExercise(
            name: "槓鈴直立划船",
            englishName: "Barbell Upright Row",
            pattern: .upperPull,
            equipment: .barbell,
            primaryMuscles: ["三角肌中束", "斜方肌"],
            techniqueCues: "握距略寬於肩，順著軀幹向上提拉至胸骨，肘高於腕，避免肩峰撞擊。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
        ),
        ResistanceExercise(
            name: "滑輪面拉 (Face Pull)",
            englishName: "Cable Face Pull",
            pattern: .upperPull,
            equipment: .cable,
            primaryMuscles: ["三角肌後束", "旋轉肌袖", "斜方肌"],
            techniqueCues: "滑輪調至眼睛高度，向面部拉開繩索同時外旋小臂，強化肩部健康與姿態。",
            defaultSets: 3,
            defaultReps: 15,
            defaultRestSeconds: 60,
            defaultRepRange: "3 組 x 12-15 次"
        ),
        ResistanceExercise(
            name: "引體向上 (正手/反手)",
            englishName: "Pull-Ups / Chin-Ups",
            pattern: .upperPull,
            equipment: .bodyweight,
            primaryMuscles: ["背闊肌", "二頭肌", "菱形肌"],
            techniqueCues: "沉肩啟動背部發力，下巴過槓，頂部擠壓肩胛骨，離心慢放。",
            defaultSets: 4,
            defaultReps: 8,
            defaultRestSeconds: 120,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "高位滑輪下拉 (器械纜繩)",
            englishName: "Lat Pulldown (Cable)",
            pattern: .upperPull,
            equipment: .cable,
            primaryMuscles: ["背闊肌", "大圓肌"],
            techniqueCues: "挺胸微後仰，肩胛下沉下拉橫槓至鎖骨下方，不借助爆發力。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
            defaultRepRange: "3-4 組 x 8-12 次"
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
            defaultRestSeconds: 120,
            defaultRepRange: "3-4 組 x 6-10 次"
        ),
        ResistanceExercise(
            name: "坐姿滑輪划船 (器械纜繩)",
            englishName: "Seated Cable Row",
            pattern: .upperPull,
            equipment: .cable,
            primaryMuscles: ["菱形肌", "中斜方肌", "背闊肌"],
            techniqueCues: "雙腳踩穩踏板，脊柱直立挺胸，向後拉手把至肚臍，頂峰擠壓肩胛骨。",
            defaultSets: 3,
            defaultReps: 10,
            defaultRestSeconds: 90,
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
            defaultRestSeconds: 60,
            defaultRepRange: "3 組 x 8-12 次"
        )
    ]
    
    /// 依部位獲取動作清單
    public static func exercises(for pattern: MovementPattern) -> [ResistanceExercise] {
        return allExercises.filter { $0.pattern == pattern }
    }
    
    /// 依器材獲取動作清單
    public static func exercises(for equipment: EquipmentType) -> [ResistanceExercise] {
        return allExercises.filter { $0.equipment == equipment }
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
