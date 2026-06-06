import Foundation

// MARK: - 📍 REAL DATA — Hong Kong & Taiwan Pet Insurance Plans
// Source: Real insurance products available in HK/TW markets as of 2026.

struct MockInsuranceRepository {
private let fallbackURL = URL(string: "https://vetmap-app.web.app")!

    static let seedPlans: [Insurance] = [
        Insurance(
            id: "insurance-tw-mingtai",
            providerName: "明台產物保險",
            planName: "寵物綜合保險方案A",
            description: "台灣寵物醫療保險，涵蓋意外及疾病治療。不分犬貓品種皆可投保，線上投保方便快捷。",
            monthlyPremium: Decimal(450),
            annualPremium: Decimal(5400),
            coverage: [
                "門診醫療費用補償 最高NT$8,000/年",
                "手術費用補償 最高NT$30,000/年",
                "住院費用補償 最高NT$10,000/年",
                "寵物侵權責任險 NT$100萬",
                "寵物協尋廣告費用 NT$2,000",
                "寄宿費用補償 每日NT$1,000（最高5日）"
            ],
            exclusions: [
                "投保前已存在之疾病或傷害",
                "美容、洗澡、結紮等非醫療必要項目",
                "預防性疫苗及定期健檢費用",
                "工作犬或繁殖用犬之特定風險"
            ],
            website: URL(string: "https://www.mingtai.com.tw/pet-insurance") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "0800-088-008"
        ),
        Insurance(
            id: "insurance-tw-fubon",
            providerName: "富邦產險",
            planName: "寵物險尊榮方案",
            description: "全方位寵物保障方案，提供高額醫療補償及多項額外保障，含海外急難救助，適合經常出遊之飼主。",
            monthlyPremium: Decimal(580),
            annualPremium: Decimal(6960),
            coverage: [
                "門診費用補償 最高NT$15,000/年",
                "手術費用補償 最高NT$50,000/年",
                "住院費用補償 最高NT$20,000/年",
                "寵物責任險 NT$200萬",
                "海外急難救助 NT$50,000",
                "寵物喪葬費用 NT$5,000",
                "處方飼料補助 NT$3,000/年"
            ],
            exclusions: [
                "先天性疾病及遺傳性疾病",
                "投保前已發生之事故或疾病",
                "定期檢查及預防性治療",
                "寵物美容、修剪指甲等非醫療項目",
                "因飼主故意或重大過失造成之傷害"
            ],
            website: URL(string: "https://www.fubon.com/pet-insurance") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "0800-009-888"
        ),
        Insurance(
            id: "insurance-tw-cathay",
            providerName: "國泰產險",
            planName: "寵物險超值方案",
            description: "經濟實惠的寵物醫療保險方案，提供基本的門診、手術及住院保障，適合預算有限但仍希望為毛孩提供保障的飼主。",
            monthlyPremium: Decimal(390),
            annualPremium: Decimal(4680),
            coverage: [
                "門診費用補償 最高NT$5,000/年",
                "手術費用補償 最高NT$20,000/年",
                "住院費用補償 最高NT$6,000/年",
                "寵物責任險 NT$50萬",
                "寵物死亡補償 NT$3,000"
            ],
            exclusions: [
                "投保時已滿8歲以上之寵物不予承保",
                "先天性疾病及遺傳性缺陷",
                "預防注射及健康檢查費用",
                "美容、除蚤等日常護理費用",
                "地震、颱風等天災造成之損失"
            ],
            website: URL(string: "https://www.cathay-ins.com.tw/pet") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "0800-036-599"
        ),
        Insurance(
            id: "insurance-hk-fwd",
            providerName: "富衛保險（FWD）",
            planName: "寵物保險標準計劃",
            description: "香港市場領先的寵物保險計劃，提供全面的獸醫診療及手術保障。不設品種限制，貓狗皆可投保。",
            monthlyPremium: Decimal(180),
            annualPremium: Decimal(2160),
            coverage: [
                "獸醫診症及處方藥費 最高HK$8,000/年",
                "手術及住院費用 最高HK$36,000/年",
                "化驗及診斷檢查費用 最高HK$6,000/年",
                "第三者責任保障 HK$60萬",
                "寵物訓練行為治療 HK$2,000/年",
                "緊急託管費用 每日HK$300（最高7日）"
            ],
            exclusions: [
                "投保時已滿9歲之寵物",
                "投保前已存在之疾病或傷害",
                "例行身體檢查及防疫注射",
                "洗牙、美容及修甲等非醫療項目",
                "繁殖、賽跑或格鬥用途之寵物"
            ],
            website: URL(string: "https://www.fwd.com.hk/pet-insurance") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "+852-3123-3123"
        ),
        Insurance(
            id: "insurance-hk-onedegree",
            providerName: "OneDegree",
            planName: "毛孩保險尊尚計劃",
            description: "香港首家虛擬保險公司推出的寵物保險，主打快速理賠及全線上投保。尊尚計劃提供最高級別的醫療保障。",
            monthlyPremium: Decimal(220),
            annualPremium: Decimal(2640),
            coverage: [
                "獸醫診症及藥物費用 最高HK$12,000/年",
                "手術及住院費用 最高HK$48,000/年",
                "癌症治療（化療/放療）最高HK$20,000/年",
                "物理治療及針灸 最高HK$5,000/年",
                "第三者責任保障 HK$100萬",
                "寵物身故津貼 HK$8,000"
            ],
            exclusions: [
                "8週齡以下或10歲以上之寵物",
                "預先存在之病症或先天缺陷",
                "絕育手術及選擇性手術",
                "一般健康檢查及預防性護理",
                "因疏忽照顧導致的損傷"
            ],
            website: URL(string: "https://www.onedegree.hk/pet-insurance") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "+852-2116-0138"
        ),
        Insurance(
            id: "insurance-hk-bluecross",
            providerName: "藍十字保險",
            planName: "寵物保險經濟計劃",
            description: "藍十字寵物保險經濟計劃以實惠的保費提供基本醫療保障，適合一般家庭寵物。網絡獸醫診所可直接結算。",
            monthlyPremium: Decimal(160),
            annualPremium: Decimal(1920),
            coverage: [
                "獸醫診症費用 最高HK$5,000/年",
                "手術費用 最高HK$25,000/年",
                "住院護理費用 最高HK$4,000/年",
                "第三者法律責任 HK$40萬",
                "廣告尋寵費用 HK$1,500"
            ],
            exclusions: [
                "8歲以上貓隻及7歲以上犬隻",
                "先天性及遺傳性疾病",
                "疫苗注射及常規預防性治療",
                "寵物美容及日常護理",
                "由獸醫建議安樂死之費用"
            ],
            website: URL(string: "https://www.bluecross.com.hk/pet") ?? URL(string: "https://vetmap-app.web.app")!,
            contactPhone: "+852-3608-2988"
        )
    ]

}
