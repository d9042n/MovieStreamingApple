//
//  AppDelegate.swift
//  MovieStreamingApple
//
//  Dynamic orientation control:
//  - iPhone: portrait-only by default, landscape allowed ONLY when player is active
//  - iPad: all orientations always allowed (iPadOS handles multitasking natively)
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Global flag set by PlayerPageView to allow landscape on iPhone.
    /// Must be `@MainActor` because it's read from the main-thread-only
    /// `application(_:supportedInterfaceOrientationsFor:)` callback.
    @MainActor static var allowLandscapeOnPhone = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // iPad: allow all orientations (iPadOS manages rotation natively)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }

        // iPhone: only allow landscape when the player is active
        if AppDelegate.allowLandscapeOnPhone {
            return .allButUpsideDown
        }

        // Default: portrait-only on iPhone
        return .portrait
    }
}
