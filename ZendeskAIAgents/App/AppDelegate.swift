//
//  AppDelegate.swift
//  ZendeskAIAgents
//
//  App entry point. Boots the Zendesk Messaging SDK lazily on first use
//  (after credentials are configured). All app-wide state lives here.
//

import UIKit
import ZendeskSDKMessaging

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // Shared services
    let credentialsStore = CredentialsStore()
    lazy var zendeskInitializer = ZendeskInitializer(credentialsStore: credentialsStore)
    lazy var authService = JWTAuthService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
