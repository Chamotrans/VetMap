import Foundation

// MARK: - ⚠️ DUMMY SEED DATA — 僅供開發測試用，上線前需替換為真實資料
// 所有 static let seedProducts 內的產品資料（名稱、價格、描述等）皆為虛構，
// 僅用於開發與測試。上線前請替換為 Firebase 或其他真實資料來源。

struct MockProductRepository {
    static let seedProducts: [PetProduct] = [
        PetProduct(
            id: "product-royal-canin-f32",
            name: "皇家F32理想體態貓糧",
            description: "專為成貓設計的均衡營養配方，含高消化蛋白質與適量纖維，有助維持理想體態。適合1-7歲成貓每日食用。",
            category: "食品",
            price: Decimal(1200),
            currency: "TWD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/royal-canin-f32"),
            imageURL: nil,
            tags: ["貓糧", "成貓", "皇家"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-hills-cd",
            name: "希爾思處方糧 c/d 貓用泌尿道配方",
            description: "獸醫推薦的處方糧，專為貓隻下泌尿道健康設計。含控制鎂含量及抗氧化配方，有助減少結晶形成風險。需經獸醫評估後使用。",
            category: "食品",
            price: Decimal(2400),
            currency: "TWD",
            clinicId: "taipei-anxin",
            affiliateURL: URL(string: "https://example.com/affiliate/hills-cd"),
            imageURL: nil,
            tags: ["處方糧", "貓用", "泌尿道", "希爾思"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-frontline-plus",
            name: "蚤不到 Plus 貓用滴劑",
            description: "外用滴劑，有效預防及治療跳蚤、壁蝨及耳疥蟲感染。每月使用一劑，適用於8週齡以上之貓咪。",
            category: "藥品",
            price: Decimal(750),
            currency: "TWD",
            clinicId: "taipei-greenpaw",
            affiliateURL: URL(string: "https://example.com/affiliate/frontline-plus"),
            imageURL: nil,
            tags: ["驅蟲", "貓用", "外用滴劑"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-probiotic",
            name: "寵特寶 寵物益生菌",
            description: "含多種活性益生菌株及益生元，有助維持腸道菌群平衡。適合腹瀉、軟便或食慾不振之犬貓。粉末狀可直接拌入飼料。",
            category: "保健",
            price: Decimal(680),
            currency: "TWD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/pet-probiotic"),
            imageURL: nil,
            tags: ["益生菌", "腸胃保健", "犬貓通用"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-scratcher",
            name: "瓦楞紙貓抓板 雙面L型",
            description: "高密度瓦楞紙製成，雙面L型設計可躺可抓。內附貓薄荷，吸引貓咪使用，保護家具免受抓傷。",
            category: "玩具",
            price: Decimal(299),
            currency: "TWD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/cat-scratcher"),
            imageURL: nil,
            tags: ["貓抓板", "瓦楞紙", "貓薄荷"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-petkit-fountain",
            name: "Petkit Eversweet 智能飲水機",
            description: "三層過濾系統，有效去除雜質及異味。智能模式根據寵物飲水習慣調整出水頻率，靜音設計適合家居使用。2公升大容量。",
            category: "玩具",
            price: Decimal(398),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/petkit-fountain"),
            imageURL: nil,
            tags: ["飲水機", "智能", "貓狗通用"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-fish-oil",
            name: "寵物魚油 Omega-3 軟膠囊",
            description: "萃取自深海魚類之高純度Omega-3脂肪酸，有助皮膚毛髮健康、關節保養及心血管維護。適合皮膚敏感或年長寵物日常保養。",
            category: "保健",
            price: Decimal(220),
            currency: "HKD",
            clinicId: "hk-harbour",
            affiliateURL: URL(string: "https://example.com/affiliate/pet-fish-oil"),
            imageURL: nil,
            tags: ["魚油", "皮膚毛髮", "關節保健"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-nexgard",
            name: "全能狗S 中型犬 咀嚼錠",
            description: "口服驅蟲咀嚼錠，同時預防心絲蟲、跳蚤、壁蝨及腸道寄生蟲。每月一錠，牛肉口味適口性佳。適用7.5-15kg中型犬。",
            category: "藥品",
            price: Decimal(850),
            currency: "HKD",
            clinicId: "hk-kowloon-care",
            affiliateURL: URL(string: "https://example.com/affiliate/nexgard"),
            imageURL: nil,
            tags: ["驅蟲", "犬用", "口服", "心絲蟲"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-nutri-gel",
            name: "維克 Nutri-Plus 營養膏",
            description: "高能量營養補充膏，含維生素、礦物質及氨基酸。適合病後康復、食慾不振或高活動量之犬貓。亦可作為懷孕及哺乳期營養補充。",
            category: "保健",
            price: Decimal(350),
            currency: "TWD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/nutri-gel"),
            imageURL: nil,
            tags: ["營養膏", "補充品", "犬貓通用"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        ),
        PetProduct(
            id: "product-pet-camera",
            name: "Furbo 寵物互動攝影機",
            description: "1080p 高清寵物攝影機，支援雙向語音通話及零食投擲功能。AI 吠叫偵測即時推送通知，讓你隨時與毛孩互動。",
            category: "玩具",
            price: Decimal(2380),
            currency: "TWD",
            clinicId: nil,
            affiliateURL: URL(string: "https://example.com/affiliate/furbo"),
            imageURL: nil,
            tags: ["攝影機", "互動", "智能"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000)
        )
    ]
}
