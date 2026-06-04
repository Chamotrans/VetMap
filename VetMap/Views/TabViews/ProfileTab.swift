import SwiftUI

struct ProfileTab: View {
    var body: some View {
        ComingSoonView(
            title: "我的",
            subtitle: "登入、收藏診所與會員訂閱會接在 Firebase Auth 後面。",
            systemImage: "person.crop.circle.fill"
        )
    }
}
