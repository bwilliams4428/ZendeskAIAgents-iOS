//
//  SceneDelegate.swift
//  ZendeskAIAgents
//
//  Decides the root view controller based on whether credentials are configured.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        window.rootViewController = makeRootViewController(appDelegate: appDelegate)
        self.window = window
        window.makeKeyAndVisible()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(credentialsDidChange),
            name: .zendeskCredentialsChanged,
            object: nil
        )
    }

    @objc private func credentialsDidChange() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        window?.rootViewController = makeRootViewController(appDelegate: appDelegate)
    }

    private func makeRootViewController(appDelegate: AppDelegate) -> UIViewController {
        if appDelegate.credentialsStore.hasCredentials {
            return UINavigationController(rootViewController: HomeViewController())
        } else {
            return UINavigationController(
                rootViewController: CredentialsSetupViewController(
                    credentialsStore: appDelegate.credentialsStore
                )
            )
        }
    }
}
