import SwiftUI

struct FavoriteButton: View {
    let clinicID: String
    @AppStorage("favorites") private var favoritesData: String = "[]"
    
    private var favorites: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(favoritesData.utf8))) ?? []
    }
    
    private var isFavorite: Bool {
        favorites.contains(clinicID)
    }
    
    var body: some View {
        Button {
            var list = favorites
            if list.contains(clinicID) {
                list.removeAll { $0 == clinicID }
            } else {
                list.append(clinicID)
            }
            if let data = try? JSONEncoder().encode(list) {
                favoritesData = String(data: data, encoding: .utf8) ?? "[]"
            }
            Haptics.light()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? .red : .gray)
                .font(.title3)
        }
        .accessibilityLabel(isFavorite ? "取消收藏" : "收藏診所")
    }
}
