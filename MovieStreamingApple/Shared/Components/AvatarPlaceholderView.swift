//
//  AvatarPlaceholderView.swift
//  MovieStreamingApple
//
//  Shared placeholder avatar used across PeopleView, PersonDetailView,
//  and DetailCastView. Displays the first letter of a name on a gradient.
//

import SwiftUI

struct AvatarPlaceholderView: View {
    let name: String
    var fontSize: CGFloat = 28

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.colors.link.opacity(0.4),
                    themeManager.colors.brand.opacity(0.4),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(String(name.prefix(1)).uppercased())
                .font(ThemeFont.display(size: fontSize, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
