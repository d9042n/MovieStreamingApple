//
//  ContentTab.swift
//  MovieStreamingApple
//
//  Tab filter options shared by Movies and Series sections.
//

import Foundation

/// Tab filter options shared by Movies and Series sections.
enum ContentTab: String, CaseIterable, Identifiable, Sendable {
    case popular
    case comingSoon = "coming-soon"
    case topRated = "top-rated"
    case latest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popular: return "Phổ Biến"
        case .comingSoon: return "Sắp Chiếu"
        case .topRated: return "Đánh Giá Cao"
        case .latest: return "Mới Nhất"
        }
    }
}
