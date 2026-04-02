//
//  PersonNavigation.swift
//  MovieStreamingApple
//
//  Lightweight navigation value for navigating to PersonDetailView from any page.
//

import Foundation

/// A Hashable navigation value to push PersonDetailView onto a NavigationStack.
struct PersonNavigation: Hashable {
    let slug: String
}
