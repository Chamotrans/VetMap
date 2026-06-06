import Foundation

// MARK: - 📍 REAL DATA — Hong Kong Pet Supply Stores
// Source: petcircle-hk.vercel.app — Real HK pet supply stores

struct MockProductRepository {
    // MARK: - REAL DATA — Hong Kong Pet Supply Stores
    // Source: petcircle-hk.vercel.app
    static let seedProducts: [PetProduct] = [
        PetProduct(
            id: "product-pc-001",
            name: "MYZOO動物緣",
            description: "位於香港香港嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(100),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-002",
            name: "Lego Pet 樂高寵物 (又新街 Yau San Street)",
            description: "位於香港元朗區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(150),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-003",
            name: "天下貓貓一樣貓（元朗站）",
            description: "位於香港元朗區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(200),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-004",
            name: "Chill•愛貓 Chill Love Cats",
            description: "位於香港觀塘區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(250),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-005",
            name: "天下貓貓一樣貓(大圍站)",
            description: "位於香港沙田區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(300),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-006",
            name: "PetsOrder 寵物網 ( Fanling 粉嶺 )",
            description: "位於香港北區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(350),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-007",
            name: "PetsOrder 寵物網 (Hoi Pa St. 海壩街)",
            description: "位於香港荃灣區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(400),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-008",
            name: "Lego Pet 樂高寵物 ( 葵涌廣場 KWAI CHUNG PLAZA )",
            description: "位於香港葵青區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(450),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-009",
            name: "Lego Pet 樂高寵物 ( TMT Plaza 屯門市廣場)",
            description: "位於香港屯門區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(500),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-010",
            name: "Petroom 萌寵天地",
            description: "位於香港黃大仙區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(550),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-011",
            name: "Lego Pet 樂高寵物 (觀塘 Kwun Tong)",
            description: "位於香港觀塘區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(600),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-012",
            name: "One Woof Club",
            description: "位於香港香港嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(650),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-013",
            name: "Furbabies' Meal 毛孩膳食｜寵物鮮食包",
            description: "位於香港沙田區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(700),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-014",
            name: "Hidden Gems",
            description: "位於香港荃灣區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(750),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        ),
        PetProduct(
            id: "product-pc-015",
            name: "毛嘆生活",
            description: "位於香港屯門區嘅寵物用品店，提供寵物食品、用品及配件。",
            category: "保健",
            price: Decimal(800),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["寵物用品"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        )
    ]}
